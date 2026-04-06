class Admin::AccountMergerController < InertiaController
  layout "inertia"

  before_action :require_ultraadmin!

  def show
    render inertia: "Admin/AccountMerger", props: {
      search_url: search_users_admin_account_merger_path,
      merge_url: merge_admin_account_merger_path
    }
  end

  def search_users
    query_term = params[:query].to_s.downcase.strip
    return render json: [] if query_term.blank?

    users = User.search_identity(query_term)
      .includes(:email_addresses)
      .select(
        "users.*, " \
        "CASE WHEN LOWER(users.username) = #{ActiveRecord::Base.connection.quote(query_term)} " \
        "THEN 0 ELSE 1 END AS exact_match_rank"
      )
      .order(Arel.sql("exact_match_rank ASC, users.username ASC"))
      .limit(20)

    results = users.map { |user| format_user(user) }

    render json: results
  end

  def merge
    older_id = params[:older_id].to_i
    newer_id = params[:newer_id].to_i

    if older_id == newer_id
      redirect_to admin_account_merger_path, alert: "Cannot merge a user into themselves."
      return
    end

    older_user = User.find_by(id: older_id)
    newer_user = User.find_by(id: newer_id)

    unless older_user && newer_user
      redirect_to admin_account_merger_path, alert: "One or both users not found."
      return
    end

    if newer_user.created_at < older_user.created_at
      redirect_to admin_account_merger_path, alert: "The NEWER user (right side) must have been created after the OLDER user (left side). #{newer_user.display_name} was created #{newer_user.created_at.to_date} which is before #{older_user.display_name} created #{older_user.created_at.to_date}."
      return
    end

    merge_results = perform_merge(older_user, newer_user)

    redirect_to admin_account_merger_path, notice: "Merge complete! #{merge_results}"
  rescue => e
    Rails.logger.error("Account merge failed and was rolled back: #{e.message}")
    redirect_to admin_account_merger_path, alert: "Merge failed and was rolled back: #{e.message}"
  end

  private

  def require_ultraadmin!
    unless current_user&.admin_level == "ultraadmin"
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end

  def format_user(user)
    {
      id: user.id,
      display_name: user.display_name,
      avatar_url: user.avatar_url,
      created_at: user.created_at&.strftime("%Y-%m-%d"),
      username: user.username,
      email: user.email_addresses.first&.email
    }
  end

  def perform_merge(older_user, newer_user)
    results = []

    ActiveRecord::Base.transaction do
      # 1. Move heartbeats from newer to older
      heartbeat_count = Heartbeat.where(user_id: newer_user.id).update_all(user_id: older_user.id)
      results << "#{heartbeat_count} heartbeats moved"

      # 2. Transfer API keys from newer to older
      api_key_count = ApiKey.where(user_id: newer_user.id).update_all(user_id: older_user.id)
      results << "#{api_key_count} API keys transferred"

      # 3. Transfer goals from newer to older
      goal_count = newer_user.goals.update_all(user_id: older_user.id)
      results << "#{goal_count} goals transferred"

      # 4. Revoke newer user's sessions
      revoked_tokens = 0
      revoked_tokens += newer_user.sign_in_tokens.destroy_all.count
      revoked_tokens += Doorkeeper::AccessToken.where(resource_owner_id: newer_user.id).update_all(revoked_at: Time.current)
      revoked_tokens += Doorkeeper::AccessGrant.where(resource_owner_id: newer_user.id).update_all(revoked_at: Time.current)
      results << "#{revoked_tokens} sessions/tokens revoked"

      # 5. Delete all related data for the newer user
      deleted_records = 0
      deleted_records += newer_user.email_addresses.destroy_all.count
      deleted_records += newer_user.email_verification_requests.destroy_all.count
      deleted_records += newer_user.goals.destroy_all.count
      deleted_records += newer_user.admin_api_keys.destroy_all.count
      deleted_records += ProjectRepoMapping.where(user_id: newer_user.id).delete_all
      deleted_records += newer_user.heartbeat_import_runs.destroy_all.count
      deleted_records += delete_rows("heartbeat_import_sources", user_id: newer_user.id)
      deleted_records += delete_rows("instance_import_sources", user_id: newer_user.id)
      deleted_records += delete_rows("wakatime_mirrors", user_id: newer_user.id)
      deleted_records += Commit.where(user_id: newer_user.id).delete_all
      deleted_records += RepoHostEvent.where(user_id: newer_user.id).delete_all
      deleted_records += TrustLevelAuditLog.where(user_id: newer_user.id).delete_all
      deleted_records += TrustLevelAuditLog.where(changed_by_id: newer_user.id).delete_all
      deleted_records += DeletionRequest.where(user_id: newer_user.id).delete_all
      deleted_records += LeaderboardEntry.where(user_id: newer_user.id).delete_all
      deleted_records += Doorkeeper::Application.where(owner_id: newer_user.id, owner_type: "User").destroy_all.count
      Doorkeeper::AccessToken.where(resource_owner_id: newer_user.id).delete_all
      Doorkeeper::AccessGrant.where(resource_owner_id: newer_user.id).delete_all
      deleted_records += delete_rows("project_labels", user_id: newer_user.id.to_s)
      deleted_records += PaperTrail::Version.where(item_type: "User", item_id: newer_user.id).delete_all
      results << "#{deleted_records} related records cleaned up"

      # 6. Finally, delete the newer user
      newer_user.reload
      newer_user.destroy!
      results << "user ##{newer_user.id} deleted"
    end

    results.join(", ")
  end

  DELETABLE_TABLES = %w[heartbeat_import_sources instance_import_sources wakatime_mirrors project_labels].freeze

  def delete_rows(table_name, conditions)
    raise ArgumentError, "Table '#{table_name}' is not in the allowlist" unless table_name.in?(DELETABLE_TABLES)

    sanitized = ActiveRecord::Base.sanitize_sql_array(
      [ conditions.map { |col, _| "#{ActiveRecord::Base.connection.quote_column_name(col)} = ?" }.join(" AND "), *conditions.values ]
    )
    ActiveRecord::Base.connection.delete("DELETE FROM #{ActiveRecord::Base.connection.quote_table_name(table_name)} WHERE #{sanitized}")
  end
end
