class Cache::HomeStatsJob < Cache::ActivityJob
  queue_as :latency_5m

  private

  def calculate
    if HeartbeatRepository.clickhouse?
      archived_projects = ProjectRepoMapping.archived.pluck(:user_id, :project_name)
      return HeartbeatRepository.current.home_stats(archived_projects:)
    end

    users_tracked, seconds_tracked = DashboardRollup
      .where(dimension: DashboardRollup::TOTAL_DIMENSION).where(total_seconds: 1..)
      .pick(Arel.sql("COUNT(*), COALESCE(SUM(total_seconds), 0)"))
    { users_tracked: users_tracked || 0, seconds_tracked: seconds_tracked || 0 }
  end
end
