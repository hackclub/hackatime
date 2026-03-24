class Cache::ActiveUsersGraphDataJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    # over the last 24 hours, count the number of people who were active each hour
    connection = Heartbeat.connection
    hours = connection.select_all(<<~SQL
      SELECT
        toInt64(toUInt32(time) / 3600) * 3600 AS hour,
        uniq(user_id) AS count
      FROM (#{Heartbeat.coding_only.with_valid_timestamps.where("time > ?", 24.hours.ago.to_f).where("time < ?", Time.current.to_f).to_sql}) AS hb
      GROUP BY hour
      ORDER BY hour DESC
    SQL
    )

    top_hour_count = hours.map { |h| h["count"].to_i }.max || 1

    hours = hours.map do |h|
      {
        hour: Time.at(h["hour"].to_i),
        users: h["count"].to_i,
        height: (h["count"].to_f / top_hour_count * 100).round
      }
    end
  end
end
