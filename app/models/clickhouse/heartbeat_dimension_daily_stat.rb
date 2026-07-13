module Clickhouse
  class HeartbeatDimensionDailyStat < Clickhouse::Record
    self.table_name = "heartbeat_dimension_daily_stats"
    self.primary_key = nil

    class << self
      def seconds_for(user_id:, dimension:, value:, start_date: nil, end_date: nil)
        relation = where(user_id: user_id, dimension: dimension.to_s, value: Array(value).map(&:to_s))
        relation = relation.where(day: start_date..end_date) if start_date && end_date

        return relation.sum(:seconds).to_f.round unless start_date && end_date

        grouped_sql = relation
          .select(Arel.sql("day, sum(seconds) AS seconds, sum(first_seconds) AS first_seconds, sum(heartbeat_count) AS heartbeat_count"))
          .group(:day)
          .to_sql

        connection.select_value(<<~SQL.squish).to_f.round
          SELECT sum(seconds) - argMin(first_seconds, day)
          FROM (#{grouped_sql}) AS grouped_days
          WHERE heartbeat_count > 0
        SQL
      end

      def durations_for(user_id:, dimension:, start_date: nil, end_date: nil)
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
            rows.sort_by! { |row| Date.parse(row["day"].to_s) }
            (rows.sum { |row| row["seconds"].to_f } - rows.first["first_seconds"].to_f).round
          end
      end
    end
  end
end
