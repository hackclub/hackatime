class Cache::ActiveUsersGraphDataJob < Cache::ActivityJob
  queue_as :latency_10s

  # `EXTRACT(EPOCH FROM to_timestamp(time))::bigint / 3600 * 3600` (rounding to
  # microseconds, then half up to seconds) in integer arithmetic, which is much
  # cheaper per row than numeric.
  HOUR_SQL = "(ROUND((time - 946684800) * 1000000)::bigint + 946684800500000) / 1000000 / 3600 * 3600".freeze

  private

  def calculate
    # Distinct (hour, user) pairs hash-aggregate instead of sorting every
    # heartbeat for COUNT(DISTINCT user_id).
    pairs = Heartbeat.coding_only.with_valid_timestamps
      .where("time > ?", 24.hours.ago.to_f).where("time < ?", Time.current.to_f)
      .select(Arel.sql("#{HOUR_SQL} AS hour"), :user_id).distinct
    # The planner expects about as many pairs as heartbeats and so would not
    # gather them from parallel workers; cheaper tuple transfer lets it.
    # ActivityJob#perform runs this in a transaction.
    Heartbeat.connection.execute("SET LOCAL parallel_tuple_cost = 0.01")
    hours = Heartbeat.unscoped.from(pairs, :pairs).select("hour, COUNT(*) AS count").group("hour").order("hour DESC")

    top = hours.max_by(&:count)&.count || 1
    hours.map { |h| { hour: Time.at(h.hour), users: h.count, height: (h.count.to_f / top * 100).round } }
  end
end
