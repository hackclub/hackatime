class Cache::CurrentlyHackingJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration = 5.minutes

  def calculate
    latest_project_by_user = Clickhouse::Heartbeat
      .where(source_type: Heartbeat.source_types.fetch("direct_entry")).coding_only
      .where("time > ?", 5.minutes.ago.to_f)
      .group(:user_id)
      .pluck(Arel.sql("user_id, argMax(ifNull(project, ''), tuple(time, fields_hash))"))
      .to_h

    users = User.where(id: latest_project_by_user.keys)
                .includes(:project_repo_mappings, :email_addresses).to_a

    active_projects = {}
    users.each do |user|
      mapping = user.project_repo_mappings.find { |p| p.project_name == latest_project_by_user[user.id] }
      active_projects[user.id] = mapping&.archived? ? nil : mapping
    end

    users = users.sort_by { |u| [ active_projects[u.id].present? ? 0 : 1, u.display_name.present? ? 0 : 1 ] }
    { users:, active_projects: }
  end
end
