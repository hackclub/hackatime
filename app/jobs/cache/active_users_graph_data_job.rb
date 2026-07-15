class Cache::ActiveUsersGraphDataJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    inner = Clickhouse::Heartbeat.coding_only.with_valid_timestamps
      .where("time > ?", 24.hours.ago.to_f).where("time < ?", Time.current.to_f)
      .select(Arel.sql("intDiv(toInt64(round(time)), 3600) * 3600 AS hour, COUNT(DISTINCT user_id) AS count"))
      .group(Arel.sql("hour")).order(Arel.sql("hour DESC"))
      .to_sql

    hours = begin
      Clickhouse::Heartbeat.connection.select_all(inner).map { |row| { hour: row["hour"].to_i, count: row["count"].to_i } }
    rescue ActiveRecord::ActiveRecordError => e
      raise unless e.message.include?("undefined method 'map' for nil")

      []
    end

    top = hours.max_by { |h| h[:count] }&.fetch(:count) || 1
    hours.map { |h| { hour: Time.at(h[:hour]), users: h[:count], height: (h[:count].to_f / top * 100).round } }
  end
end
