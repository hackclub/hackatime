class Cache::ActiveProjectsJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def cache_expiration
    15.minutes
  end

  def calculate
    # Query recent heartbeats from ClickHouse
    recent_hbs = Heartbeat.where(source_type: Heartbeat.source_types[:direct_entry])
                          .where("time > ?", 5.minutes.ago.to_f)
                          .order(time: :desc)
                          .to_a

    # Deduplicate by user_id (most recent heartbeat per user)
    latest_by_user = recent_hbs.group_by(&:user_id).transform_values(&:first)

    return {} if latest_by_user.empty?

    # Find matching project_repo_mappings from Postgres
    user_ids = latest_by_user.keys

    mappings = ProjectRepoMapping.active
                                 .where(user_id: user_ids)
                                 .to_a

    result = {}
    latest_by_user.each do |user_id, hb|
      mapping = mappings.find { |m| m.user_id == user_id && m.project_name == hb.project }
      result[user_id] = mapping if mapping
    end

    result
  end
end
