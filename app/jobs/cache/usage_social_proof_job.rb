class Cache::UsageSocialProofJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    counts = distinct_user_counts

    if counts[:past_hour_count] > 5
      past_hour_count = counts[:past_hour_count]
      "In the past hour, #{past_hour_count} Hack Clubbers have coded with Hackatime."
    elsif counts[:past_day_count] > 5
      past_day_count = counts[:past_day_count]
      "In the past day, #{past_day_count} Hack Clubbers have coded with Hackatime."
    elsif counts[:past_week_count] > 5
      past_week_count = counts[:past_week_count]
      "In the past week, #{past_week_count} Hack Clubbers have coded with Hackatime."
    end
  end

  def distinct_user_counts
    past_hour = 1.hour.ago.to_f
    past_day = 1.day.ago.to_f
    past_week = 1.week.ago.to_f

    conn = Heartbeat.connection
    result = conn.select_one(<<~SQL)
      SELECT
        COUNT(DISTINCT user_id) FILTER (WHERE time > #{conn.quote(past_hour)})::integer AS past_hour_count,
        COUNT(DISTINCT user_id) FILTER (WHERE time > #{conn.quote(past_day)})::integer AS past_day_count,
        COUNT(DISTINCT user_id) FILTER (WHERE time > #{conn.quote(past_week)})::integer AS past_week_count
      FROM heartbeats
      WHERE deleted_at IS NULL
        AND category = 'coding'
        AND time IS NOT NULL
        AND time >= 0 AND time <= 253402300799
        AND time > #{conn.quote(past_week)}
    SQL

    {
      past_hour_count: result["past_hour_count"].to_i,
      past_day_count: result["past_day_count"].to_i,
      past_week_count: result["past_week_count"].to_i
    }
  end
end
