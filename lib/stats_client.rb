class StatsClient
  RUST_URL = ENV.fetch("STATS_SERVER_URL", "http://stats_server:4000")
  AUTH_TOKEN = ENV.fetch("STATS_SERVER_AUTH_TOKEN", "dev-token")
  TIMEOUT = 30 # seconds

  class Error < StandardError; end
  class ConnectionError < Error; end
  class ServerError < Error; end

  def self.duration(user_id: nil, user_ids: nil, start_time: nil, end_time: nil, **opts)
    body = compact({
      user_id: user_id, user_ids: user_ids,
      start_time: start_time&.to_f, end_time: end_time&.to_f,
      **opts
    })
    post("/api/v1/duration", body)
  end

  def self.duration_grouped(group_by:, user_id: nil, user_ids: nil, start_time: nil, end_time: nil, **opts)
    body = compact({
      user_id: user_id, user_ids: user_ids,
      group_by: group_by.to_s,
      start_time: start_time&.to_f, end_time: end_time&.to_f,
      **opts
    })
    post("/api/v1/duration/grouped", body)
  end

  def self.duration_boundary_aware(user_id:, start_time:, end_time:, **opts)
    body = compact({
      user_id: user_id,
      start_time: start_time.to_f, end_time: end_time.to_f,
      **opts
    })
    post("/api/v1/duration/boundary-aware", body)
  end

  def self.spans(user_id:, start_time: nil, end_time: nil, **opts)
    body = compact({
      user_id: user_id,
      start_time: start_time&.to_f, end_time: end_time&.to_f,
      **opts
    })
    post("/api/v1/spans", body)
  end

  def self.daily_durations(user_id:, timezone:, start_date: nil, end_date: nil)
    body = compact({
      user_id: user_id, timezone: timezone,
      start_date: start_date&.to_s, end_date: end_date&.to_s
    })
    post("/api/v1/daily-durations", body)
  end

  def self.streaks(user_ids:, start_date: nil, min_daily_seconds: nil)
    body = compact({
      user_ids: user_ids,
      start_date: start_date&.to_s,
      min_daily_seconds: min_daily_seconds
    })
    post("/api/v1/streaks", body)
  end

  def self.summary(user_id:, start_time: nil, end_time: nil, group_by: nil, **opts)
    body = compact({
      user_id: user_id,
      start_time: start_time&.to_f, end_time: end_time&.to_f,
      group_by: group_by,
      **opts
    })
    post("/api/v1/stats/summary", body)
  end

  def self.profile_stats(user_id:, timezone:, **opts)
    body = compact({
      user_id: user_id, timezone: timezone,
      **opts
    })
    post("/api/v1/stats/profile", body)
  end

  def self.leaderboard_compute(start_time:, end_time:, user_ids: nil, **opts)
    body = compact({
      user_ids: user_ids,
      start_time: start_time.to_f, end_time: end_time.to_f,
      **opts
    })
    post("/api/v1/leaderboard/compute", body)
  end

  def self.unique_seconds(user_id:, start_time:, end_time:, **opts)
    body = compact({
      user_id: user_id,
      start_time: start_time.to_f, end_time: end_time.to_f,
      **opts
    })
    post("/api/v1/unique-seconds", body)
  end

  def self.duration_batch(user_id:, start_time:, end_time:, queries:, **opts)
    body = compact({
      user_id: user_id,
      start_time: start_time.to_f, end_time: end_time.to_f,
      queries: queries,
      **opts
    })
    post("/api/v1/duration/batch", body)
  end

  private

  def self.post(path, body)
    response = HTTP
      .timeout(TIMEOUT)
      .auth("Bearer #{AUTH_TOKEN}")
      .post("#{RUST_URL}#{path}", json: body)

    unless response.status.success?
      raise ServerError, "Stats server returned #{response.status}: #{response.body}"
    end

    JSON.parse(response.body.to_s)
  rescue HTTP::ConnectionError, HTTP::TimeoutError => e
    raise ConnectionError, "Failed to connect to stats server: #{e.message}"
  end

  def self.compact(hash)
    hash.reject { |_, v| v.nil? }
  end
end
