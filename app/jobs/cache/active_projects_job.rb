class Cache::ActiveProjectsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration = 15.minutes

  def calculate
    if HeartbeatRepository.clickhouse?
      recent = HeartbeatRepository.current.latest_direct_heartbeats(
        since: 5.minutes.ago.to_f,
        coding_only: false,
        per_project: true
      )
      return {} if recent.empty?

      mappings = ProjectRepoMapping.active
        .where(user_id: recent.pluck("user_id"), project_name: recent.pluck("project").compact)
        .index_by { |mapping| [ mapping.user_id, mapping.project_name ] }
      return recent.filter_map do |row|
        user_id = row.fetch("user_id").to_i
        mapping = mappings[[ user_id, row["project"] ]]
        [ user_id, row, mapping ] if mapping
      end.group_by(&:first).transform_values do |candidates|
        candidates.max_by { |_user_id, row, _mapping| [ row.fetch("latest_time").to_f, row.fetch("latest_id").to_i ] }.last
      end
    end

    sql = ProjectRepoMapping.sanitize_sql_array([ <<~SQL, Heartbeat.source_types[:direct_entry], 5.minutes.ago.to_f ])
      WITH recent AS MATERIALIZED (
        SELECT id, user_id, project, time
        FROM heartbeats
        WHERE source_type = ?
          AND deleted_at IS NULL
          AND time > ?
      )
      SELECT DISTINCT ON (recent.user_id) project_repo_mappings.*, recent.user_id
      FROM project_repo_mappings
      INNER JOIN recent
        ON recent.project = project_repo_mappings.project_name
        AND recent.user_id = project_repo_mappings.user_id
      INNER JOIN users ON users.id = recent.user_id
      WHERE project_repo_mappings.archived_at IS NULL
      ORDER BY recent.user_id, recent.time DESC, recent.id DESC
    SQL

    ProjectRepoMapping.find_by_sql(sql).index_by(&:user_id)
  end
end
