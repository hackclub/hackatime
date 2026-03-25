class Cache::ActiveProjectsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration
    15.minutes
  end

  def calculate
    latest_by_user = latest_projects_by_user_id

    return {} if latest_by_user.empty?

    mappings = ProjectRepoMapping.active
                                 .where(user_id: latest_by_user.keys)
                                 .to_a
                                 .group_by(&:user_id)

    result = {}
    latest_by_user.each do |user_id, project_name|
      mapping = (mappings[user_id] || []).find { |candidate| candidate.project_name == project_name }
      result[user_id] = mapping if mapping
    end

    result
  end

  def latest_projects_by_user_id
    rows = Heartbeat.connection.select_all(Heartbeat.sanitize_sql([ <<~SQL, Heartbeat.source_types[:direct_entry], 5.minutes.ago.to_f ]))
      SELECT user_id, argMax(project, time) AS project
      FROM heartbeats
      WHERE source_type = ?
        AND time > ?
      GROUP BY user_id
    SQL

    rows.each_with_object({}) do |row, hash|
      hash[row["user_id"].to_i] = row["project"]
    end
  end
end
