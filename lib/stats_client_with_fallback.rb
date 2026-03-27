# lib/stats_client_with_fallback.rb
# Migration-phase wrapper that falls back to Ruby when the Rust server is unavailable.
# Remove this once the Rust server is stable and all call sites are migrated.
class StatsClientWithFallback
  def self.duration(user_id: nil, start_time: nil, end_time: nil, **opts)
    StatsClient.duration(user_id: user_id, start_time: start_time, end_time: end_time, **opts)
  rescue StatsClient::ConnectionError => e
    Rails.logger.warn "Stats server unavailable, falling back to Ruby: #{e.message}"
    scope = Heartbeat.all
    scope = scope.where(user_id: user_id) if user_id
    scope = scope.where("time >= ?", start_time) if start_time
    scope = scope.where("time <= ?", end_time) if end_time
    scope = scope.coding_only if opts[:coding_only]
    { "total_seconds" => scope.duration_seconds }
  end

  def self.duration_grouped(group_by:, user_id: nil, start_time: nil, end_time: nil, **opts)
    StatsClient.duration_grouped(group_by: group_by, user_id: user_id, start_time: start_time, end_time: end_time, **opts)
  rescue StatsClient::ConnectionError => e
    Rails.logger.warn "Stats server unavailable, falling back to Ruby: #{e.message}"
    scope = Heartbeat.all
    scope = scope.where(user_id: user_id) if user_id
    scope = scope.where("time >= ?", start_time) if start_time
    scope = scope.where("time <= ?", end_time) if end_time
    scope = scope.coding_only if opts[:coding_only]
    { "groups" => scope.group(group_by).duration_seconds }
  end

  def self.duration_boundary_aware(user_id:, start_time:, end_time:, **opts)
    StatsClient.duration_boundary_aware(user_id: user_id, start_time: start_time, end_time: end_time, **opts)
  rescue StatsClient::ConnectionError => e
    Rails.logger.warn "Stats server unavailable, falling back to Ruby: #{e.message}"
    scope = Heartbeat.where(user_id: user_id)
    scope = scope.where(project: opts[:project]) if opts[:project]
    { "total_seconds" => Heartbeat.duration_seconds_boundary_aware(scope, start_time, end_time) }
  end

  def self.daily_durations(user_id:, timezone:, start_date: nil, end_date: nil)
    StatsClient.daily_durations(user_id: user_id, timezone: timezone, start_date: start_date, end_date: end_date)
  rescue StatsClient::ConnectionError => e
    Rails.logger.warn "Stats server unavailable, falling back to Ruby: #{e.message}"
    scope = User.find(user_id).heartbeats
    scope = scope.where("time >= ?", start_date.to_time.to_f) if start_date
    scope = scope.where("time <= ?", end_date.to_time.to_f) if end_date
    results = scope.daily_durations(user_timezone: timezone, start_date: start_date, end_date: end_date)
    { "durations" => results.to_h }
  end

  def self.streaks(user_ids:, start_date: nil, min_daily_seconds: nil)
    StatsClient.streaks(user_ids: user_ids, start_date: start_date, min_daily_seconds: min_daily_seconds)
  rescue StatsClient::ConnectionError => e
    Rails.logger.warn "Stats server unavailable, falling back to Ruby: #{e.message}"
    result = Heartbeat.daily_streaks_for_users(user_ids, start_date: start_date)
    { "streaks" => result.transform_keys(&:to_s) }
  end

  def self.method_missing(method, *, **)
    StatsClient.public_send(method, *, **)
  end

  def self.respond_to_missing?(method, include_private = false)
    StatsClient.respond_to?(method) || super
  end
end
