module Clickhouse
  class HeartbeatDimensionAttributionDailyStat < Clickhouse::Record
    self.table_name = "heartbeat_dimension_attribution_daily_stats"
    self.primary_key = nil

    class << self
      def durations_for(user_id:, dimension:, start_date: nil, end_date: nil, range_first_day: nil)
        relation = where(user_id: user_id, dimension: dimension.to_s)
        relation = relation.where(day: start_date..end_date) if start_date && end_date

        unless start_date && end_date
          return relation.group(:value).sum(:seconds).transform_values { |seconds| seconds.to_f.round }
        end

        sql = relation
          .select(Arel.sql("value, day, sum(seconds) AS seconds, sum(first_seconds) AS first_seconds, sum(heartbeat_count) AS heartbeat_count"))
          .group(:value, :day)
          .order(:value, :day)
          .to_sql

        connection.select_all("SELECT * FROM (#{sql}) AS grouped_rows WHERE heartbeat_count > 0")
          .group_by { |row| row["value"] }
          .transform_values do |rows|
            (rows.sum { |row| row["seconds"].to_f } - rows.sum { |row|
              Date.parse(row["day"].to_s) == range_first_day ? row["first_seconds"].to_f : 0
            }).round
          end
      end
    end
  end
end
