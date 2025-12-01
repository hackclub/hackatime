class Cache::ActiveProjectsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration
    15.minutes
  end

  def calculate
    # Get recent heartbeats with matching project_repo_mappings in a single SQL query
    ProjectRepoMapping.joins("INNER JOIN heartbeats ON heartbeats.project = project_repo_mappings.project_name AND heartbeats.user_id = project_repo_mappings.user_id")
                      .joins("INNER JOIN users ON users.id = heartbeats.user_id")
                      .where("heartbeats.source_type = ?", Heartbeat.source_types[:direct_entry])
                      .where("heartbeats.time > ?", 5.minutes.ago.to_f)
                      .select("DISTINCT ON (heartbeats.user_id) project_repo_mappings.*, heartbeats.user_id")
                      .order("heartbeats.user_id, heartbeats.time DESC")
                      .index_by(&:user_id)
  end
end
