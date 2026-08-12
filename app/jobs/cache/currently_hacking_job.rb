class Cache::CurrentlyHackingJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration = 5.minutes

  def calculate
    if HeartbeatRepository.clickhouse?
      recent_heartbeats = HeartbeatRepository.current.latest_direct_heartbeats(since: 5.minutes.ago.to_f)
        .index_by { |row| row.fetch("user_id").to_i }
      users = User.where(id: recent_heartbeats.keys)
        .includes(:project_repo_mappings, :email_addresses).to_a
      active_projects = users.to_h do |user|
        heartbeat = recent_heartbeats.fetch(user.id)
        mapping = user.project_repo_mappings.find { |candidate| candidate.project_name == heartbeat["project"] }
        [ user.id, mapping&.archived? ? nil : mapping ]
      end
      users.sort_by! { |user| [ active_projects[user.id].present? ? 0 : 1, user.display_name.present? ? 0 : 1 ] }
      return { users:, active_projects: }
    end

    recent_heartbeats = Heartbeat.joins(:user)
      .where(source_type: :direct_entry).coding_only
      .where("time > ?", 5.minutes.ago.to_f)
      .select("DISTINCT ON (user_id) user_id, project, time, users.*")
      .order("user_id, time DESC, heartbeats.id DESC")
      .includes(user: [ :project_repo_mappings, :email_addresses ])
      .index_by(&:user_id)

    users = recent_heartbeats.values.map(&:user)
    active_projects = {}
    users.each do |user|
      mapping = user.project_repo_mappings.find { |p| p.project_name == recent_heartbeats[user.id]&.project }
      active_projects[user.id] = mapping&.archived? ? nil : mapping
    end

    users = users.sort_by { |u| [ active_projects[u.id].present? ? 0 : 1, u.display_name.present? ? 0 : 1 ] }
    { users:, active_projects: }
  end
end
