class StatsClient
  RUST_URL = if Rails.env.test?
    ENV.fetch("TEST_STATS_SERVER_URL", "http://stats_server_test:4001")
  else
    ENV.fetch("STATS_SERVER_URL", "http://stats_server:4000")
  end
  AUTH_TOKEN = ENV.fetch("STATS_SERVER_AUTH_TOKEN", "dev-token")
  TIMEOUT = 30 # seconds

  class Error < StandardError; end
  class ConnectionError < Error; end
  class ServerError < Error; end

  def self.duration(user_id: nil, user_ids: nil, start_time: nil, end_time: nil, **opts)
    body = compact({
      user_id: user_id, user_ids: user_ids,
      start_time: unix_seconds(start_time), end_time: unix_seconds(end_time),
      **opts
    })
    post("/api/v1/duration", body)
  end

  def self.duration_grouped(group_by:, user_id: nil, user_ids: nil, start_time: nil, end_time: nil, **opts)
    body = compact({
      user_id: user_id, user_ids: user_ids,
      group_by: group_by.to_s,
      start_time: unix_seconds(start_time), end_time: unix_seconds(end_time),
      **opts
    })
    normalize_grouped_response(post("/api/v1/duration/grouped", body))
  end

  def self.duration_boundary_aware(user_id:, start_time:, end_time:, **opts)
    body = compact({
      user_id: user_id,
      start_time: unix_seconds(start_time), end_time: unix_seconds(end_time),
      **opts
    })
    post("/api/v1/duration/boundary-aware", body)
  end

  def self.spans(user_id:, start_time: nil, end_time: nil, **opts)
    body = compact({
      user_id: user_id,
      start_time: unix_seconds(start_time), end_time: unix_seconds(end_time),
      **opts
    })
    post("/api/v1/spans", body)
  end

  def self.daily_durations(user_id:, timezone:, start_date: nil, end_date: nil)
    body = compact({
      user_id: user_id, timezone: timezone,
      start_date: start_date&.to_s, end_date: end_date&.to_s
    })
    normalize_daily_durations_response(post("/api/v1/daily-durations", body))
  end

  def self.streaks(user_ids:, start_date: nil, min_daily_seconds: nil)
    body = compact({
      user_ids: user_ids,
      start_date: start_date&.to_s,
      min_daily_seconds: min_daily_seconds
    })
    normalize_streaks_response(post("/api/v1/streaks", body))
  end

  def self.summary(user_id:, start_time: nil, end_time: nil, group_by: nil, **opts)
    body = compact({
      user_id: user_id,
      start_time: unix_seconds(start_time), end_time: unix_seconds(end_time),
      group_by: Array.wrap(group_by).presence&.map(&:to_s),
      **opts
    })
    post("/api/v1/stats/summary", body)
  end

  def self.profile_stats(user_id:, timezone:, **opts)
    body = compact({
      user_id: user_id, timezone: timezone,
      **opts
    })
    normalize_profile_response(post("/api/v1/stats/profile", body))
  end

  def self.leaderboard_compute(start_time:, end_time:, user_ids: nil, **opts)
    body = compact({
      user_ids: user_ids,
      start_time: unix_seconds(start_time), end_time: unix_seconds(end_time),
      **opts
    })
    post("/api/v1/leaderboard/compute", body)
  end

  def self.unique_seconds(user_id:, start_time:, end_time:, **opts)
    body = compact({
      user_id: user_id,
      start_time: unix_seconds(start_time), end_time: unix_seconds(end_time),
      **opts
    })
    post("/api/v1/unique-seconds", body)
  end

  def self.duration_batch(user_id:, start_time:, end_time:, queries:, **opts)
    body = compact({
      user_id: user_id,
      start_time: unix_seconds(start_time), end_time: unix_seconds(end_time),
      queries: queries,
      **opts
    })
    normalize_batch_response(post("/api/v1/duration/batch", body))
  end

  def self.exclusive_end_time(value)
    seconds = unix_seconds(value)
    return nil if seconds.nil?
    return seconds if seconds.is_a?(Float) && seconds != seconds.to_i

    seconds.to_f - 1e-6
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

  def self.unix_seconds(value)
    return nil if value.nil?

    numeric = case value
    when Numeric then value
    when Time, DateTime then value.to_f
    when Date then value.to_time.to_f
    else
      value.to_time.to_f
    end

    seconds = numeric.to_f
    seconds == seconds.to_i ? seconds.to_i : seconds
  rescue ArgumentError, NoMethodError, TypeError
    nil
  end

  def self.normalize_grouped_response(payload)
    groups = normalize_named_durations(payload["groups"])
    payload.merge("groups" => groups)
  end

  def self.normalize_daily_durations_response(payload)
    durations = case payload["durations"]
    when Hash
      payload["durations"].transform_values(&:to_i)
    else
      Array(payload["durations"]).each_with_object({}) do |entry, acc|
        acc[entry["date"]] = entry["total_seconds"].to_i
      end
    end
    payload.merge("durations" => durations)
  end

  def self.normalize_streaks_response(payload)
    streaks = case payload["streaks"]
    when Hash
      payload["streaks"].transform_keys(&:to_s).transform_values(&:to_i)
    else
      Array(payload["streaks"]).each_with_object({}) do |entry, acc|
        acc[entry["user_id"].to_s] = entry["streak_count"].to_i
      end
    end
    payload.merge("streaks" => streaks)
  end

  def self.normalize_profile_response(payload)
    payload.merge(
      "top_languages" => normalize_named_durations(payload["top_languages"]),
      "top_projects" => normalize_named_durations(payload["top_projects"]),
      "top_projects_month" => normalize_project_durations(payload["top_projects_month"]),
      "top_editors" => normalize_named_durations(payload["top_editors"])
    )
  end

  def self.normalize_named_durations(entries)
    case entries
    when Hash
      entries.transform_values(&:to_i)
    else
      Array(entries).each_with_object({}) do |entry, acc|
        acc[entry["name"]] = entry["total_seconds"].to_i
      end
    end
  end

  def self.normalize_project_durations(entries)
    Array(entries).map do |entry|
      if entry.key?("project")
        {
          "project" => entry["project"],
          "duration" => entry["duration"].to_i
        }
      else
        {
          "project" => entry["name"],
          "duration" => entry["total_seconds"].to_i
        }
      end
    end
  end

  def self.normalize_batch_response(payload)
    normalized_results = payload.fetch("results", {}).transform_values do |result|
      result.key?("groups") ? normalize_grouped_response(result) : result
    end
    payload.merge("results" => normalized_results)
  end
end
