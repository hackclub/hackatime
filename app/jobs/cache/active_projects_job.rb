class Cache::ActiveProjectsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration = 15.minutes

  def calculate
    # The recent-heartbeats set (last 5 min) is tiny, so we materialize it first
    # and join outward. Filtering heartbeats.deleted_at inline instead makes the
    # planner abandon the index-only scan and fall into a per-mapping nested loop
    # (measured ~380x slower on prod), so keep this shape.
    sql = ProjectRepoMapping.sanitize_sql_array([ <<~SQL, Heartbeat.source_types[:direct_entry], 5.minutes.ago.to_f ])
      WITH recent AS MATERIALIZED (
        SELECT user_id, project, time
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
      ORDER BY recent.user_id, recent.time DESC
    SQL

    ProjectRepoMapping.find_by_sql(sql).index_by(&:user_id)
  end
end
