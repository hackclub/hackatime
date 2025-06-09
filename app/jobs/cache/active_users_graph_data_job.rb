class Cache::ActiveUsersGraphDataJob < Cache::ActivityJob
  queue_as :latency_10s

  private

  def calculate
    # over the last 24 hours, count the number of people who were active each hour
    hours = Heartbeat.coding_only
                     .with_valid_timestamps
                     .where("time > ?", 24.hours.ago.to_f)
                     .where("time < ?", Time.current.to_f)
                     .select("(EXTRACT(EPOCH FROM to_timestamp(time))::bigint / 3600 * 3600) as hour, COUNT(DISTINCT user_id) as count")
                     .group("hour")
                     .order("hour DESC")

    top_hour_count = hours.max_by(&:count)&.count || 1

    hours = hours.map do |h|
      {
        hour: Time.at(h.hour),
        users: h.count,
        height: (h.count.to_f / top_hour_count * 100).round
      }
    end
  end
end
