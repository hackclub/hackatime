class HeartbeatRemapRunner
  SNAPSHOT_FIELDS = %w[user_id language fields_hash deleted_at time_epoch].freeze
  ACTIVE_STATES = %w[queued running].freeze
  TRANSIENT_ERRORS = [
    ActiveRecord::Deadlocked,
    ActiveRecord::SerializationFailure,
    ActiveRecord::RecordNotUnique
  ].freeze

  def self.start!(dry_run: true, batch_size: HeartbeatRemapRun::DEFAULT_BATCH_SIZE)
    HeartbeatRemapRun.create!(
      dry_run:,
      batch_size:,
      max_heartbeat_id: Heartbeat.with_deleted.maximum(:id) || 0,
      rule_ids: HeartbeatRemapper::REGISTRY.map { |rule| rule::ID }
    )
  end

  def self.process_batch!(run)
    affected_user_ids = []

    begin
      HeartbeatRemapRun.transaction do
        run.lock!
        return run unless ACTIVE_STATES.include?(run.state)
        unless run.rule_ids == HeartbeatRemapper::REGISTRY.map { |rule| rule::ID }
          raise ArgumentError, "Heartbeat remap rules changed after this run started"
        end

        run.update_columns(state: HeartbeatRemapRun.states.fetch("running"), started_at: run.started_at || Time.current)
        ids = candidate_ids(run)
        if ids.empty?
          complete!(run)
          next
        end

        heartbeats = Heartbeat.with_deleted.where(id: ids).order(:id).lock.to_a
        users_by_id = User.where(id: heartbeats.map(&:user_id)).index_by(&:id)
        plans = heartbeats.filter_map { |heartbeat| build_plan(heartbeat, users_by_id[heartbeat.user_id]) }
        collision_rows = Heartbeat.where(fields_hash: plans.map { |plan| plan[:post_hash] }.uniq)
          .where.not(id: plans.map { |plan| plan[:heartbeat].id }).order(:id).lock.to_a

        outcome = plan_outcome(plans, collision_rows, dry_run: run.dry_run?)
        alias_changes = plan_alias_changes(outcome)
        persist_changes(run, outcome[:audits])
        persist_alias_changes(run, alias_changes)
        unless run.dry_run?
          bulk_update_heartbeats(outcome[:updates])
          apply_alias_changes(alias_changes)
          affected_user_ids = outcome[:updates].filter_map { |update| update[:active_change] ? update[:user_id] : nil }.uniq
        end

        run.update_columns(
          cursor_id: ids.last,
          scanned_count: run.scanned_count + ids.length,
          changed_count: run.changed_count + plans.length,
          deduplicated_count: run.deduplicated_count + outcome[:deduplicated_count],
          stale_count: run.stale_count + outcome[:stale_count],
          unsafe_count: run.unsafe_count + outcome[:unsafe_count],
          updated_at: Time.current
        )
        complete!(run) if ids.last >= run.max_heartbeat_id
      end
    rescue *TRANSIENT_ERRORS
      raise
    rescue => error
      run.update_columns(
        state: HeartbeatRemapRun.states.fetch("failed"),
        error_count: run.error_count + 1,
        error_message: error.message,
        finished_at: Time.current,
        updated_at: Time.current
      ) if run.persisted?
      raise
    end

    affected_user_ids.each { |user_id| DashboardRollupRefreshJob.schedule_for(user_id) }
    run
  end

  def self.start_rollback!(run)
    raise ArgumentError, "Dry runs do not change heartbeats" if run.dry_run?
    raise ArgumentError, "Only completed runs can be rolled back" unless run.completed?

    run.update!(
      state: :rolling_back,
      finished_at: nil,
      error_message: nil
    )
  end

  def self.rollback_batch!(run)
    affected_user_ids = []

    HeartbeatRemapRun.transaction do
      run.lock!
      return run unless run.rolling_back?

      changes = pending_rollback_changes(run)
      if changes.empty?
        finish_rollback!(run)
        next
      end

      heartbeats_by_id = Heartbeat.with_deleted.where(id: changes.map(&:heartbeat_id)).order(:id).lock.index_by(&:id)
      updates = []
      stale_count = 0
      changes.each do |change|
        heartbeat = heartbeats_by_id[change.heartbeat_id]
        next unless change.action_update? || change.action_duplicate_soft_delete?

        unless heartbeat && snapshot_matches?(heartbeat, change.postimage)
          stale_count += 1
          next
        end

        updates << update_from_snapshot(heartbeat, change.preimage)
      end

      updates, collision_stale_count = reject_occupied_restores(updates)
      stale_count += collision_stale_count
      bulk_update_heartbeats(updates)
      alias_changes = run.remap_alias_changes.where(heartbeat_id: changes.map(&:heartbeat_id), rolled_back_at: nil).lock.to_a
      alias_stale_count = rollback_alias_changes(alias_changes, restored_heartbeat_ids: updates.map { |update| update[:id] })
      stale_count += alias_stale_count
      affected_user_ids = updates.map { |update| update[:user_id] }.uniq
      now = Time.current
      HeartbeatRemapChange.where(id: changes.map(&:id)).update_all(rolled_back_at: now, updated_at: now)
      HeartbeatRemapAliasChange.where(id: alias_changes.map(&:id)).update_all(rolled_back_at: now, updated_at: now)
      run.update_columns(
        stale_count: run.stale_count + stale_count,
        updated_at: now
      )
      finish_rollback!(run) unless run.remap_changes.where(rolled_back_at: nil).exists?
    end

    affected_user_ids.each { |user_id| DashboardRollupRefreshJob.schedule_for(user_id) }
    run
  end

  def self.schedule_rollups!(run)
    return if run.dry_run?

    affected_users = run.remap_changes.where(action: %w[update duplicate_soft_delete])
      .where("preimage ->> 'deleted_at' IS NULL")
      .select("(preimage ->> 'user_id')::bigint")
    User.where(id: affected_users).select(:id).find_each(batch_size: run.batch_size) do |user|
      DashboardRollupRefreshJob.schedule_for(user.id)
    end
  end

  def self.candidate_ids(run)
    Heartbeat.with_deleted
      .where(id: (run.cursor_id + 1)..run.max_heartbeat_id)
      .order(:id).limit(run.batch_size).pluck(:id)
  end
  private_class_method :candidate_ids

  def self.pending_rollback_changes(run)
    pending = run.remap_changes.where(rolled_back_at: nil)
    action = %w[update duplicate_soft_delete].find { |candidate| pending.where(action: candidate).exists? }
    pending = pending.where(action:) if action
    pending.order(id: :desc).limit(run.batch_size).to_a
  end
  private_class_method :pending_rollback_changes

  def self.build_plan(heartbeat, user)
    result = HeartbeatRemapper.call(heartbeat.attributes)
    return if result.rule_ids.empty?

    corrected = heartbeat.dup
    corrected.assign_attributes(result.attributes.slice(*HeartbeatRemapper::WRITABLE_FIELDS))
    corrected.user = user
    unless corrected.valid?
      return {
        heartbeat:,
        preimage: snapshot_for(heartbeat),
        postimage: snapshot_for(heartbeat),
        rule_ids: result.rule_ids,
        stale: true
      }
    end

    post_hash = Heartbeat.generate_fields_hash(corrected.attributes)
    {
      heartbeat:,
      preimage: snapshot_for(heartbeat),
      corrected_attributes: result.attributes.slice(*HeartbeatRemapper::WRITABLE_FIELDS),
      post_hash:,
      post_identity: Heartbeat.identity_attributes(corrected.attributes),
      rule_ids: result.rule_ids
    }
  end
  private_class_method :build_plan

  def self.plan_outcome(plans, collision_rows, dry_run:)
    outcome = {
      audits: [], updates: [], aliases: [], alias_redirects: [],
      deduplicated_count: 0, stale_count: 0, unsafe_count: 0
    }
    stale_plans, valid_plans = plans.partition { |plan| plan[:stale] }
    stale_plans.each do |plan|
      outcome[:audits] << audit_for(plan[:heartbeat], :stale, plan[:rule_ids], plan[:preimage], plan[:postimage])
      outcome[:stale_count] += 1
    end

    valid_plans.partition { |plan| plan[:heartbeat].deleted_at.present? }.then do |deleted_plans, active_plans|
      deleted_plans.each { |plan| add_update(outcome, plan, dry_run:) }
      active_plans.group_by { |plan| plan[:post_hash] }.each_value do |group|
        collisions = collision_rows.select { |heartbeat| heartbeat.fields_hash == group.first[:post_hash] }
        identities = group.map { |plan| plan[:post_identity] } + collisions.map { |heartbeat| Heartbeat.identity_attributes(heartbeat.attributes) }
        unless identities.all? { |identity| identity == identities.first }
          group.each do |plan|
            outcome[:audits] << audit_for(
              plan[:heartbeat], :unsafe_collision, plan[:rule_ids], plan[:preimage], plan[:preimage]
            )
            outcome[:unsafe_count] += 1
          end
          next
        end

        winner = (group.map { |plan| plan[:heartbeat] } + collisions).min_by(&:id)
        group.each do |plan|
          if plan[:heartbeat].id == winner.id
            add_update(outcome, plan, dry_run:)
          else
            add_duplicate(
              outcome, plan[:heartbeat], winner, plan[:rule_ids], plan[:post_hash],
              language: group.first[:corrected_attributes][:language], dry_run:
            )
          end
        end
        collisions.reject { |heartbeat| heartbeat.id == winner.id }.each do |heartbeat|
          add_duplicate(
            outcome, heartbeat, winner, group.first[:rule_ids], group.first[:post_hash],
            language: group.first[:corrected_attributes][:language], dry_run:
          )
        end
      end
    end
    outcome
  end
  private_class_method :plan_outcome

  def self.add_update(outcome, plan, dry_run:)
    heartbeat = plan[:heartbeat]
    postimage = plan[:preimage].merge(
      "language" => plan[:corrected_attributes][:language],
      "fields_hash" => plan[:post_hash]
    )
    outcome[:audits] << audit_for(heartbeat, :update, plan[:rule_ids], plan[:preimage], postimage)
    return if dry_run

    outcome[:updates] << {
      id: heartbeat.id,
      time_epoch: heartbeat.attributes["time_epoch"],
      user_id: heartbeat.user_id,
      language: plan[:corrected_attributes][:language],
      fields_hash: plan[:post_hash],
      deleted_at: heartbeat.deleted_at,
      active_change: heartbeat.deleted_at.nil?
    }
    outcome[:aliases] << alias_for(
      heartbeat, heartbeat.fields_hash, plan[:post_hash], heartbeat_id: heartbeat.id
    )
  end
  private_class_method :add_update

  def self.add_duplicate(outcome, heartbeat, winner, rule_ids, post_hash, language:, dry_run:)
    preimage = snapshot_for(heartbeat)
    postimage = preimage.merge("language" => language, "fields_hash" => post_hash, "deleted_at" => Time.current)
    outcome[:audits] << audit_for(heartbeat, :duplicate_soft_delete, rule_ids, preimage, postimage, winner:)
    outcome[:deduplicated_count] += 1
    return if dry_run

    outcome[:updates] << {
      id: heartbeat.id,
      time_epoch: heartbeat.attributes["time_epoch"],
      user_id: heartbeat.user_id,
      language:,
      fields_hash: post_hash,
      deleted_at: postimage["deleted_at"],
      active_change: true,
      soft_delete_first: true
    }
    outcome[:aliases] << alias_for(winner, heartbeat.fields_hash, post_hash, heartbeat_id: heartbeat.id)
    outcome[:alias_redirects] << {
      loser_id: heartbeat.id,
      winner_id: winner.id,
      canonical_hash: post_hash,
      heartbeat_id: heartbeat.id
    }
  end
  private_class_method :add_duplicate

  def self.audit_for(heartbeat, action, rule_ids, preimage, postimage, winner: nil)
    {
      heartbeat_id: heartbeat.id,
      winner_heartbeat_id: winner&.id,
      action: action.to_s,
      rule_ids:,
      preimage:,
      postimage:
    }
  end
  private_class_method :audit_for

  def self.persist_changes(run, audits)
    return if audits.empty?

    now = Time.current
    HeartbeatRemapChange.insert_all(
      audits.map { |audit| audit.merge(heartbeat_remap_run_id: run.id, created_at: now, updated_at: now) },
      unique_by: :index_heartbeat_remap_changes_on_run_and_heartbeat
    )
  end
  private_class_method :persist_changes

  def self.alias_for(winner, alias_hash, canonical_hash, heartbeat_id:)
    return if alias_hash == canonical_hash && winner.fields_hash == canonical_hash

    {
      user_id: winner.user_id,
      heartbeat_id:,
      after_heartbeat_id: winner.id,
      alias_hash:,
      after_canonical_hash: canonical_hash
    }
  end
  private_class_method :alias_for

  def self.plan_alias_changes(outcome)
    updates_by_id = outcome[:updates].index_by { |update| update[:id] }
    redirects_by_id = outcome[:alias_redirects].index_by { |redirect| redirect[:loser_id] }
    aliases = outcome[:aliases].compact
    target_ids = (updates_by_id.keys + redirects_by_id.keys).uniq
    return [] if target_ids.empty? && aliases.empty?

    existing_scope = HeartbeatHashAlias.where(heartbeat_id: target_ids)
    if aliases.any?
      existing_scope = existing_scope.or(
        HeartbeatHashAlias.where(
          user_id: aliases.pluck(:user_id).uniq,
          alias_hash: aliases.pluck(:alias_hash).uniq
        )
      )
    end
    existing = existing_scope.lock.to_a
    existing_by_key = existing.index_by { |record| [ record.user_id, record.alias_hash ] }
    desired = {}

    existing.each do |record|
      redirect = redirects_by_id[record.heartbeat_id]
      update = updates_by_id[record.heartbeat_id]
      next unless redirect || update

      desired[[ record.user_id, record.alias_hash ]] = {
        user_id: record.user_id,
        heartbeat_id: redirect ? redirect[:heartbeat_id] : update[:id],
        alias_hash: record.alias_hash,
        after_heartbeat_id: redirect ? redirect[:winner_id] : update[:id],
        after_canonical_hash: redirect ? redirect[:canonical_hash] : update[:fields_hash]
      }
    end
    aliases.each { |record| desired[[ record[:user_id], record[:alias_hash] ]] = record }

    desired.values.filter_map do |record|
      before = existing_by_key[[ record[:user_id], record[:alias_hash] ]]
      next if before&.heartbeat_id == record[:after_heartbeat_id] &&
        before.canonical_hash == record[:after_canonical_hash]

      record.merge(
        before_heartbeat_id: before&.heartbeat_id,
        before_canonical_hash: before&.canonical_hash
      )
    end
  end
  private_class_method :plan_alias_changes

  def self.persist_alias_changes(run, changes)
    return if changes.empty?

    now = Time.current
    HeartbeatRemapAliasChange.upsert_all(
      changes.map do |change|
        change.merge(heartbeat_remap_run_id: run.id, created_at: now, updated_at: now)
      end,
      unique_by: :index_heartbeat_remap_alias_changes_on_run_user_alias,
      update_only: %i[after_heartbeat_id after_canonical_hash]
    )
  end
  private_class_method :persist_alias_changes

  def self.apply_alias_changes(changes)
    return if changes.empty?

    now = Time.current
    HeartbeatHashAlias.upsert_all(
      changes.map do |change|
        {
          user_id: change[:user_id],
          heartbeat_id: change[:after_heartbeat_id],
          alias_hash: change[:alias_hash],
          canonical_hash: change[:after_canonical_hash],
          created_at: now,
          updated_at: now
        }
      end,
      unique_by: %i[user_id alias_hash],
      update_only: %i[heartbeat_id canonical_hash]
    )
  end
  private_class_method :apply_alias_changes

  def self.bulk_update_heartbeats(updates)
    return if updates.empty?

    execute_heartbeat_soft_deletes(updates.select { |update| update[:soft_delete_first] })
    execute_heartbeat_updates(updates)
  end
  private_class_method :bulk_update_heartbeats

  def self.execute_heartbeat_soft_deletes(updates)
    return if updates.empty?

    connection = Heartbeat.connection
    has_time_epoch = Heartbeat.column_names.include?("time_epoch")
    sql = if has_time_epoch
      <<~SQL
        UPDATE heartbeats
        SET deleted_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        FROM jsonb_to_recordset($1::jsonb) AS changes(id bigint, time_epoch bigint)
        WHERE heartbeats.id = changes.id
          AND heartbeats.time_epoch = changes.time_epoch
      SQL
    else
      <<~SQL
        UPDATE heartbeats
        SET deleted_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        FROM jsonb_to_recordset($1::jsonb) AS changes(id bigint)
        WHERE heartbeats.id = changes.id
      SQL
    end
    execute_json_update(connection, sql, updates.map { |update| update.slice(:id, :time_epoch) })
  end
  private_class_method :execute_heartbeat_soft_deletes

  def self.execute_heartbeat_updates(updates)
    return if updates.empty?

    connection = Heartbeat.connection
    has_time_epoch = Heartbeat.column_names.include?("time_epoch")
    sql = if has_time_epoch
      <<~SQL
        UPDATE heartbeats
        SET language = changes.language,
            fields_hash = changes.fields_hash,
            deleted_at = changes.deleted_at,
            updated_at = CURRENT_TIMESTAMP
        FROM jsonb_to_recordset($1::jsonb)
          AS changes(id bigint, language varchar, fields_hash text, deleted_at timestamp, time_epoch bigint)
        WHERE heartbeats.id = changes.id
          AND heartbeats.time_epoch = changes.time_epoch
      SQL
    else
      <<~SQL
        UPDATE heartbeats
        SET language = changes.language,
            fields_hash = changes.fields_hash,
            deleted_at = changes.deleted_at,
            updated_at = CURRENT_TIMESTAMP
        FROM jsonb_to_recordset($1::jsonb)
          AS changes(id bigint, language varchar, fields_hash text, deleted_at timestamp)
        WHERE heartbeats.id = changes.id
      SQL
    end
    payload = updates.map do |update|
      update.slice(:id, :language, :fields_hash, :deleted_at, :time_epoch)
    end
    execute_json_update(connection, sql, payload)
  end
  private_class_method :execute_heartbeat_updates

  def self.execute_json_update(connection, sql, records)
    bind = ActiveRecord::Relation::QueryAttribute.new(
      "records",
      records.to_json,
      ActiveRecord::Type::String.new
    )
    connection.exec_update(sql.squish, "Heartbeat remap batch", [ bind ])
  end
  private_class_method :execute_json_update

  def self.snapshot_for(heartbeat)
    heartbeat.attributes.slice(*SNAPSHOT_FIELDS)
  end
  private_class_method :snapshot_for

  def self.snapshot_matches?(heartbeat, snapshot)
    snapshot.slice("language", "fields_hash", "deleted_at").all? do |field, expected|
      actual = heartbeat.public_send(field)
      if field == "deleted_at"
        actual.nil? ? expected.nil? : expected.present? && (actual.to_f - expected.to_time.to_f).abs < 0.001
      else
        actual == expected
      end
    end
  end
  private_class_method :snapshot_matches?

  def self.update_from_snapshot(heartbeat, snapshot)
    {
      id: heartbeat.id,
      time_epoch: heartbeat.attributes["time_epoch"],
      user_id: heartbeat.user_id,
      language: snapshot["language"],
      fields_hash: snapshot.fetch("fields_hash"),
      deleted_at: snapshot["deleted_at"],
      active_change: heartbeat.deleted_at.nil? || snapshot["deleted_at"].nil?,
      soft_delete_first: heartbeat.deleted_at.nil? && heartbeat.fields_hash != snapshot["fields_hash"]
    }
  end
  private_class_method :update_from_snapshot

  def self.reject_occupied_restores(updates)
    active_updates = updates.select { |update| update[:deleted_at].nil? }
    occupied_hashes = Heartbeat.where(fields_hash: active_updates.pluck(:fields_hash))
      .where.not(id: updates.pluck(:id)).pluck(:fields_hash).to_set
    updates.partition { |update| update[:deleted_at].present? || !occupied_hashes.include?(update[:fields_hash]) }
      .then { |safe, stale| [ safe, stale.length ] }
  end
  private_class_method :reject_occupied_restores

  def self.rollback_alias_changes(changes, restored_heartbeat_ids:)
    eligible = changes.select { |change| restored_heartbeat_ids.include?(change.heartbeat_id) }
    return 0 if eligible.empty?

    current = HeartbeatHashAlias.where(
      user_id: eligible.map(&:user_id).uniq,
      alias_hash: eligible.map(&:alias_hash).uniq
    ).lock.to_a.index_by { |record| [ record.user_id, record.alias_hash ] }
    matched, stale = eligible.partition do |change|
      record = current[[ change.user_id, change.alias_hash ]]
      record&.heartbeat_id == change.after_heartbeat_id &&
        record.canonical_hash == change.after_canonical_hash
    end
    delete_ids = matched.filter_map do |change|
      current[[ change.user_id, change.alias_hash ]].id unless change.before_heartbeat_id
    end
    HeartbeatHashAlias.where(id: delete_ids).delete_all if delete_ids.any?

    restores = matched.filter_map do |change|
      next unless change.before_heartbeat_id

      {
        user_id: change.user_id,
        heartbeat_id: change.before_heartbeat_id,
        alias_hash: change.alias_hash,
        canonical_hash: change.before_canonical_hash,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    if restores.any?
      HeartbeatHashAlias.upsert_all(
        restores,
        unique_by: %i[user_id alias_hash],
        update_only: %i[heartbeat_id canonical_hash]
      )
    end
    stale.length
  end
  private_class_method :rollback_alias_changes

  def self.complete!(run)
    run.update_columns(
      state: HeartbeatRemapRun.states.fetch("completed"),
      finished_at: Time.current,
      updated_at: Time.current
    )
  end
  private_class_method :complete!

  def self.finish_rollback!(run)
    run.update_columns(
      state: HeartbeatRemapRun.states.fetch("rolled_back"),
      finished_at: Time.current,
      updated_at: Time.current
    )
  end
  private_class_method :finish_rollback!
end
