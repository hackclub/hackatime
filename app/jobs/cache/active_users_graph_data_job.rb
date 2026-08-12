class Cache::ActiveUsersGraphDataJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    if HeartbeatRepository.clickhouse?
      hours = HeartbeatRepository.current.active_users_by_hour(
        since: 24.hours.ago.to_f,
        before: Time.current.to_f
      )
      top = hours.map { |row| row.fetch(:count) }.max || 1
      return hours.map do |row|
        { hour: row.fetch(:hour), users: row.fetch(:count), height: (row.fetch(:count).to_f / top * 100).round }
      end
    end

    hours = Heartbeat.coding_only.with_valid_timestamps
      .where("time > ?", 24.hours.ago.to_f).where("time < ?", Time.current.to_f)
      .select("(EXTRACT(EPOCH FROM to_timestamp(time))::bigint / 3600 * 3600) as hour, COUNT(DISTINCT user_id) as count")
      .group("hour").order("hour DESC")

    top = hours.max_by(&:count)&.count || 1
    hours.map { |h| { hour: Time.at(h.hour), users: h.count, height: (h.count.to_f / top * 100).round } }
  end
end
