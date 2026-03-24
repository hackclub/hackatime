class Cache::CurrentlyHackingJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration
    5.minutes
  end

  def calculate
    # Query ClickHouse for recent heartbeats (no cross-DB join)
    raw_heartbeats = Heartbeat.where(source_type: :direct_entry)
                              .coding_only
                              .where("time > ?", 5.minutes.ago.to_f)
                              .order(time: :desc)
                              .to_a

    # Deduplicate by user_id (keep most recent)
    recent_heartbeats = raw_heartbeats.group_by(&:user_id)
                                      .transform_values(&:first)

    # Load users from Postgres
    user_ids = recent_heartbeats.keys
    users_by_id = User.where(id: user_ids)
                      .includes(:project_repo_mappings, :email_addresses)
                      .index_by(&:id)

    users = user_ids.filter_map { |uid| users_by_id[uid] }

    active_projects = {}
    users.each do |user|
      recent_heartbeat = recent_heartbeats[user.id]
      mapping = user.project_repo_mappings.find { |p| p.project_name == recent_heartbeat&.project }
      active_projects[user.id] = mapping&.archived? ? nil : mapping
    end

    users = users.sort_by do |user|
      [
        active_projects[user.id].present? ? 0 : 1,
        user.display_name.present? ? 0 : 1
      ]
    end

    { users: users, active_projects: active_projects }
  end
end
