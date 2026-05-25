class Cache::CurrentlyHackingJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration = 5.minutes

  def calculate
    recent_heartbeats = Heartbeat.joins(:user)
      .where(source_type: :direct_entry).coding_only
      .where("time > ?", 5.minutes.ago.to_f)
      .select("DISTINCT ON (user_id) user_id, project, time, users.*")
      .order("user_id, time DESC")
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
