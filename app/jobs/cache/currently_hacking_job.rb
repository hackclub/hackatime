class Cache::CurrentlyHackingJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration
    5.minutes
  end

  def calculate
    recent_heartbeats = latest_projects_by_user_id

    user_ids = recent_heartbeats.keys
    users_by_id = User.where(id: user_ids)
                      .includes(:project_repo_mappings, :email_addresses)
                      .index_by(&:id)

    users = user_ids.filter_map { |uid| users_by_id[uid] }

    active_projects = {}
    users.each do |user|
      project_name = recent_heartbeats[user.id]
      mapping = user.project_repo_mappings.find { |p| p.project_name == project_name }
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

  def latest_projects_by_user_id
    rows = Heartbeat.connection.select_all(Heartbeat.sanitize_sql([ <<~SQL, Heartbeat.source_types[:direct_entry], 5.minutes.ago.to_f ]))
      SELECT user_id, argMax(project, time) AS project
      FROM heartbeats
      WHERE source_type = ?
        AND category = 'coding'
        AND time > ?
      GROUP BY user_id
    SQL

    rows.each_with_object({}) do |row, hash|
      hash[row["user_id"].to_i] = row["project"]
    end
  end
end
