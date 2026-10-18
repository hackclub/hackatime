module Privacy
  # Coordinates the same database erasure for real and dry runs. Like the existing
  # AnonymizeUserService, it removes credentials/imports explicitly (including
  # legacy tables with no model), but physically erases the account and activity.
  class Eraser
    OWNED_TABLES = %w[
      api_keys admin_api_keys dashboard_rollups deletion_requests documentation_feedbacks
      email_addresses email_verification_requests goals heartbeat_exclusions
      heartbeat_import_runs heartbeat_import_sources heartbeats instance_import_sources
      leaderboard_entries project_labels project_repo_mappings repo_host_events
      sign_in_tokens trust_level_audit_logs wakatime_mirrors commits
    ].freeze
    USER_JOBS = %w[
      AttemptProjectRepoMappingJob DashboardRollupRefreshJob HeartbeatExportJob
      LeaderboardShadowbanExpirationJob OnboardingCheckInEmailJob PullRepoCommitsJob
      ScanGithubReposJob SlackProfileSyncJob WeeklySummaryUserEmailJob
    ].freeze
    IMPORT_JOBS = %w[HeartbeatImportJob HeartbeatImportDumpJob HeartbeatImportRemoteDownloadJob].freeze
    GLOBAL_WRITERS = %w[
      LeaderboardUpdateJob ProcessAccountDeletionsJob SailorsLogPollForChangesJob
      SlackUsernameUpdateJob UserSlackStatusUpdateJob WeeklySummaryEmailJob
      ReconcileActiveRepositoriesJob
    ].freeze

    def initialize(claims)
      @claims = claims
      @deleted = {}
      @retained = []
      @tables = {}
    end

    def call(action:)
      result = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        connection.execute("SET LOCAL lock_timeout = '2s'")
        connection.execute("SET LOCAL statement_timeout = '8s'")
        users = matched_users
        users = users.lock if action == "delete"
        @users = users.to_a
        @user_ids = @users.map(&:id)
        @emails = (@claims.dig("subject", "emails") + EmailAddress.where(user_id: @user_ids).pluck(:email)).compact.map(&:downcase).uniq
        @slack_ids = (@users.map(&:slack_uid) + [ @claims.dig("subject", "slack_id") ]).compact.uniq
        @identity_ids = (@users.map(&:hca_id) + [ @claims.dig("subject", "identity_id") ]).compact.uniq
        connection.execute("LOCK TABLE good_jobs IN SHARE ROW EXCLUSIVE MODE") if action == "delete"
        build_inventory
        build_retained_inventory
        found = @users.any? || @scopes.any? { |_, relation| relation.exists? } || @blobs.any? || @files.any? || @shared_commits.exists?

        if action == "export"
          @scopes.each { |table, relation| retain(table, relation.count, "held by Hackatime; export is read-only") }
          retain("users", @users.size, "held by Hackatime; export is read-only")
          retain("storage_objects", @blobs.size, "held by Hackatime; export is read-only")
          retain("import_files", @files.size, "held by Hackatime; export is read-only")
          retain("oauth_applications", OauthApplication.where(owner_type: "User", owner_id: @user_ids).count, "owned integrations; ownership requires manual review before deletion")
          retain("repositories", Repository.where(id: @repository_ids).count, "public repository metadata associated with the account")
          @references.each { |type, (scope, _field)| retain(type, scope.count, "other users' records referring to this administrator") }
          retain("moderation_decisions", @audit.count, "decisions about other users referring to this administrator")
          retain("shared_commit_authorship", @shared_commits.count, "author identity copied in another user's imported commits")
        elsif found
          check_manual_review!
          erase_database
          erase_files_and_cache unless @claims["dry_run"]
        end

        result = { request_id: @claims["request_id"], found: found, dry_run: @claims["dry_run"], deleted: @deleted, retained: @retained }
        raise ActiveRecord::Rollback if action == "delete" && @claims["dry_run"]
      end
      result
    rescue ActiveRecord::LockWaitTimeout, ActiveRecord::StatementInvalid => error
      raise unless error.is_a?(ActiveRecord::LockWaitTimeout) || error.cause.is_a?(PG::QueryCanceled)
      raise Error.new("work_in_progress", 503)
    end

    private

    def connection = ActiveRecord::Base.connection

    def matched_users
      subject = @claims.fetch("subject")
      emails = EmailAddress.where("LOWER(email) IN (?)", subject.fetch("emails").map(&:downcase)).select(:user_id)
      users = User.where(id: emails)
      users = users.or(User.where(slack_uid: subject["slack_id"])) if subject["slack_id"].present?
      users = users.or(User.where(hca_id: subject["identity_id"])) if subject["identity_id"].present?
      users.order(:id)
    end

    def table(name)
      @tables[name] ||= Class.new(ActiveRecord::Base) do
        self.table_name = name
        self.inheritance_column = :_disabled_sti
      end
    end

    def build_inventory
      @scopes = OWNED_TABLES.index_with { |name| table(name).where(user_id: name == "project_labels" ? @user_ids.map(&:to_s) : @user_ids) }
      @scopes["heartbeats"] = @scopes.fetch("heartbeats").annotate(HeartbeatExclusion::INCLUDE_HIDDEN_TAG)
      %w[email_verification_requests email_addresses].each do |name|
        @scopes[name] = @scopes[name].or(table(name).where("LOWER(email) IN (?)", @emails))
      end
      %w[sailors_logs sailors_log_notification_preferences sailors_log_slack_notifications].each do |name|
        @scopes[name] = table(name).where(slack_uid: @slack_ids)
      end
      messages = table("sailors_log_leaderboards").where(slack_uid: @slack_ids)
      @slack_ids.each { |id| messages = messages.or(table("sailors_log_leaderboards").where("message LIKE ?", "%<@#{ActiveRecord::Base.sanitize_sql_like(id)}>%")) }
      @scopes["sailors_log_leaderboards"] = messages
      %w[oauth_access_grants oauth_access_tokens].each { |name| @scopes[name] = table(name).where(resource_owner_id: @user_ids) }
      @scopes["mailkick_subscriptions"] = table("mailkick_subscriptions").where(subscriber_type: "User", subscriber_id: @user_ids)
      @scopes["flipper_gates"] = table("flipper_gates").where(key: "actors", value: @user_ids.map { |id| "User;#{id}" })
      @scopes["notable_requests"] = table("notable_requests").where(user_type: "User", user_id: @user_ids)
      @scopes["pghero_query_stats"] = table("pghero_query_stats").none

      @import_ids = @scopes.fetch("heartbeat_import_runs").pluck(:id)
      @repository_ids = (@scopes.fetch("project_repo_mappings").pluck(:repository_id) + @scopes.fetch("commits").pluck(:repository_id)).compact.uniq
      @leaderboard_ids = @scopes.fetch("leaderboard_entries").pluck(:leaderboard_id).uniq
      attachments = ActiveStorage::Attachment.where(record_type: "User", record_id: @user_ids)
      exports = ActiveStorage::Blob.where("metadata::jsonb @> ?::jsonb", { heartbeat_export: true }.to_json)
        .where("metadata::jsonb ->> 'user_id' IN (?)", @user_ids.map(&:to_s))
      blobs = ActiveStorage::Blob.where(id: attachments.select(:blob_id)).or(exports)
      blob_ids = blobs.pluck(:id)
      variant_ids = ActiveStorage::VariantRecord.where(blob_id: blob_ids).pluck(:id)
      variant_attachments = ActiveStorage::Attachment.where(record_type: "ActiveStorage::VariantRecord", record_id: variant_ids)
      blob_ids |= variant_attachments.pluck(:blob_id)
      attachment_ids = attachments.pluck(:id) + variant_attachments.pluck(:id)
      @blobs = ActiveStorage::Blob.where(id: blob_ids).includes(:attachments).to_a
      # A blob shared with another account cannot safely be purged automatically.
      @shared_blobs = @blobs.any? { |blob| blob.attachments.any? { |attachment| !attachment_ids.include?(attachment.id) } }
      @scopes["active_storage_attachments"] = table("active_storage_attachments").where(id: attachment_ids)
      @scopes["active_storage_variant_records"] = table("active_storage_variant_records").where(blob_id: @blobs.map(&:id))
      @scopes["active_storage_blobs"] = table("active_storage_blobs").where(id: @blobs.map(&:id))
      @files = @import_ids.flat_map { |id| Dir.glob(HeartbeatImportRunner::TMP_DIR.join("#{id}{.*,-remote.json*}").to_s) }.select { |path| File.file?(path) }.uniq
      build_job_inventory
      build_version_inventory
    end

    def build_job_inventory
      # Search JSON string values exactly, not numeric substrings (user 12 must
      # not match user 312). Numeric first arguments are scoped to their job type.
      identifiers = @emails + @slack_ids + @identity_ids + @users.map { |user| "gid://#{GlobalID.app}/User/#{user.id}" }
      candidates = table("good_jobs").none
      executions = table("good_job_executions").none
      identifiers.each do |value|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(value.to_json)}%"
        candidates = candidates.or(table("good_jobs").where("serialized_params::text ILIKE ?", pattern))
        executions = executions.or(table("good_job_executions").where("serialized_params::text ILIKE ?", pattern))
      end
      { USER_JOBS => @user_ids, IMPORT_JOBS => @import_ids,
        [ "HeartbeatExportCleanupJob" ] => @blobs.map(&:id),
        [ "SailorsLogNotifyJob" ] => @scopes.fetch("sailors_log_slack_notifications").pluck(:id)
      }.each do |classes, ids|
        candidates = candidates.or(table("good_jobs").where(job_class: classes).where("serialized_params -> 'arguments' ->> 0 IN (?)", ids.map(&:to_s)))
        executions = executions.or(table("good_job_executions").where(job_class: classes).where("serialized_params -> 'arguments' ->> 0 IN (?)", ids.map(&:to_s)))
      end
      @job_ids = candidates.pluck(:id)
      @scopes["good_jobs"] = table("good_jobs").where(id: @job_ids)
      active_ids = @scopes["good_jobs"].pluck(:active_job_id).compact
      # Executions can outlive their job row.
      @scopes["good_job_executions"] = executions.or(table("good_job_executions").where(active_job_id: active_ids))
      @scopes["notable_jobs"] = table("notable_jobs").where(job_id: active_ids.map(&:to_s))
      @batch_ids = candidates.pluck(:batch_id, :batch_callback_id).flatten.compact.uniq
      @scopes["good_job_batches"] = table("good_job_batches").where(id: @batch_ids)
    end

    def build_version_inventory
      versions = table("versions").where(item_type: "User", item_id: @user_ids).or(table("versions").where(whodunnit: @user_ids.map(&:to_s)))
      @scopes.each do |name, relation|
        next if name.start_with?("good_", "active_storage_")
        versions = versions.or(table("versions").where(item_type: name.classify, item_id: relation.select(:id))) if relation.klass.columns_hash["id"]&.type == :integer
      end
      (@emails + @slack_ids + @identity_ids).each do |value|
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
        versions = versions.or(table("versions").where("object ILIKE ? OR object_changes ILIKE ?", pattern, pattern))
        @scopes["notable_requests"] = @scopes["notable_requests"].or(table("notable_requests").where("params ILIKE ? OR url ILIKE ? OR note ILIKE ?", pattern, pattern, pattern))
        @scopes["notable_jobs"] = @scopes["notable_jobs"].or(table("notable_jobs").where("job ILIKE ? OR note ILIKE ?", pattern, pattern))
        @scopes["pghero_query_stats"] = @scopes["pghero_query_stats"].or(table("pghero_query_stats").where("query ILIKE ?", pattern))
      end
      @scopes["versions"] = versions
    end

    def build_retained_inventory
      @audit = TrustLevelAuditLog.where.not(user_id: @user_ids).where(changed_by_id: @user_ids).or(
        TrustLevelAuditLog.where.not(user_id: @user_ids).where(edited_by_id: @user_ids))
      @references = {}
      { "deletion_requests" => [ "admin_approved_by_id" ], "heartbeat_exclusions" => %w[created_by_id revoked_by_id], "users" => [ "leaderboard_shadowbanned_by_id" ] }.each do |name, fields|
        fields.each do |field|
          scope = table(name).where(field => @user_ids)
          scope = scope.where.not(name == "users" ? { id: @user_ids } : { user_id: @user_ids })
          @references["#{name}.#{field}"] = [ scope, field ]
        end
      end
      @shared_commits = Commit.none
      %w[author committer].each do |role|
        @shared_commits = @shared_commits.or(Commit.where.not(user_id: @user_ids).where("LOWER(github_raw #>> '{commit,#{role},email}') IN (?)", @emails))
        @shared_commits = @shared_commits.or(Commit.where.not(user_id: @user_ids).where("github_raw #>> '{#{role},id}' IN (?)", @users.map(&:github_uid).compact))
      end
    end

    def check_manual_review!
      if @shared_blobs || AdminApiKey.where(user_id: @user_ids, revoked_at: nil).exists? || OauthApplication.where(owner_type: "User", owner_id: @user_ids).exists?
        raise Error.new("manual_review_required", 409)
      end
      busy = GoodJob::Job.where(id: @job_ids).running.exists? ||
        GoodJob::Job.where(id: @job_ids).advisory_locked.exists? ||
        GoodJob::Job.where(id: @job_ids).where.not(locked_by_id: nil).exists? ||
        GoodJob::Job.where(job_class: GLOBAL_WRITERS).running.exists? ||
        GoodJob::Job.where(job_class: GLOBAL_WRITERS, finished_at: nil).advisory_locked.exists?
      raise Error.new("work_in_progress", 503) if busy
      # The table lock blocks row-based claims; transaction-scoped advisory
      # locks also close the race with GoodJob's advisory claim strategy.
      jobs = GoodJob::Job.where(id: @job_ids).or(GoodJob::Job.where(job_class: GLOBAL_WRITERS, finished_at: nil))
      jobs.find_each do |job|
        raise Error.new("work_in_progress", 503) unless job.advisory_lock(function: "pg_try_advisory_xact_lock")
      end
      if table("good_jobs").where(batch_id: @batch_ids).where.not(id: @job_ids).exists?
        raise Error.new("manual_review_required", 409)
      end
    end

    def erase_database
      detach_moderation
      retain("shared_commit_authorship", @shared_commits.count, "other users' imported commits; author and committer identity removed")
      @shared_commits.update_all("github_raw = github_raw - 'author' - 'committer' #- '{commit,author}' #- '{commit,committer}'")
      # Counts are the rows DELETE actually removes, not a parallel estimate.
      # Materialise IDs for polymorphic history before deleting its source rows.
      version_ids = @scopes.fetch("versions").pluck(:id)
      @scopes["versions"] = table("versions").where(id: version_ids)
      order = %w[versions good_job_executions good_jobs good_job_batches notable_jobs notable_requests
        active_storage_attachments active_storage_variant_records active_storage_blobs]
      (order + (@scopes.keys - order)).each { |name| record_deleted(name, @scopes.fetch(name).delete_all) }
      repositories = Repository.where(id: @repository_ids).where.not(id: ProjectRepoMapping.select(:repository_id).where.not(repository_id: nil))
        .where.not(id: Commit.select(:repository_id).where.not(repository_id: nil))
      record_deleted("repositories", repositories.delete_all)
      retain("repositories", Repository.where(id: @repository_ids).count, "shared public repository metadata; account association removed")
      record_deleted("users", User.where(id: @user_ids).delete_all)
      # Some installations also have an old primary-database cache table.
      record_deleted("solid_cache_entries", table("solid_cache_entries").delete_all)
      # Ranking is derived from seconds in this app; retain other participants.
      LeaderboardEntry.where(leaderboard_id: @leaderboard_ids).update_all(rank: nil)
      retain("leaderboards", @leaderboard_ids.size, "shared standings remain; display ranks are derived from the remaining participants")
      record_deleted("storage_objects", @blobs.size)
      record_deleted("import_files", @files.size)
    end

    def detach_moderation
      retain("trust_level_audit_logs", @audit.count, "decisions about other users; actor references and free-text copies removed")
      # Free text can identify its author; preserve only the decision itself.
      audit_ids = @audit.pluck(:id)
      table("versions").where(item_type: "TrustLevelAuditLog", item_id: audit_ids).then { |scope| record_deleted("versions", scope.delete_all) }
      TrustLevelAuditLog.where(id: audit_ids).update_all(reason: nil, notes: nil, original_reason: nil, original_notes: nil)
      TrustLevelAuditLog.where(changed_by_id: @user_ids).where.not(user_id: @user_ids).update_all(changed_by_id: nil)
      TrustLevelAuditLog.where(edited_by_id: @user_ids).where.not(user_id: @user_ids).update_all(edited_by_id: nil)
      @references.each do |type, (scope, field)|
        retain(type, scope.count, "other users' records; administrator reference removed")
        ids = scope.pluck(:id)
        record_deleted("versions", table("versions").where(item_type: scope.table_name.classify, item_id: ids).delete_all)
        scope.update_all(field => nil)
      end
    end

    def erase_files_and_cache
      @blobs.each do |blob|
        blob.service.delete(blob.key)
        blob.service.delete_prefixed("variants/#{blob.key}/")
      end
      @files.each { |path| File.delete(path) if File.exist?(path) }
      # Solid Cache is a separate database in production. Clear physical copies,
      # including shared payloads, before committing the account transaction.
      raise Error.new("storage_unavailable", 503) if Rails.cache.clear == false
    rescue Error
      raise
    rescue StandardError
      raise Error.new("storage_unavailable", 503)
    end

    def record_deleted(name, count)
      @deleted[name] = @deleted.fetch(name, 0) + count if count.positive?
    end

    def retain(type, count, reason)
      @retained << { type: type, count: count, reason: reason } if count.positive?
    end
  end
end
