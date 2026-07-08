class Cache::ActiveProjectsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration = 15.minutes

  def calculate
    recent = Clickhouse::Heartbeat
      .where(source_type: :direct_entry)
      .where("time > ?", 5.minutes.ago.to_f)
      .pluck(:user_id, :project, :time)
    return {} if recent.empty?

    mappings = ProjectRepoMapping
      .where(user_id: recent.map(&:first).uniq, project_name: recent.map { |row| row[1] }.compact.uniq)
      .where(archived_at: nil)
      .index_by { |mapping| [ mapping.user_id, mapping.project_name ] }

    # Latest recent heartbeat per user that has an active repo mapping.
    recent.sort_by { |_, _, time| -time }.each_with_object({}) do |(user_id, project, _), result|
      next if result.key?(user_id)

      mapping = mappings[[ user_id, project ]]
      result[user_id] = mapping if mapping
    end
  end
end
