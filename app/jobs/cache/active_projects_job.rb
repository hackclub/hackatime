class Cache::ActiveProjectsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration = 15.minutes

  def calculate
    recent_projects = Clickhouse::Heartbeat
      .where(source_type: :direct_entry)
      .where("time > ?", 5.minutes.ago.to_f)
      .group(:user_id, :project)
      .pluck(:user_id, :project, Arel.sql("max(time) AS latest_time"))
    return {} if recent_projects.empty?

    user_ids = recent_projects.map(&:first).uniq
    project_names = recent_projects.map { |_, project, _| project }.compact.uniq

    mappings = ProjectRepoMapping
      .where(user_id: user_ids, project_name: project_names)
      .where(archived_at: nil)
      .index_by { |mapping| [ mapping.user_id, mapping.project_name ] }

    # Latest recent heartbeat per user that has an active repo mapping.
    recent_projects.sort_by { |_, _, time| -time.to_f }.each_with_object({}) do |(user_id, project, _), result|
      next if result.key?(user_id)

      mapping = mappings[[ user_id, project ]]
      result[user_id] = mapping if mapping
    end
  end
end
