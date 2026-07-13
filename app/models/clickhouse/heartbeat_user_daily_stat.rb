module Clickhouse
  class HeartbeatUserDailyStat < Clickhouse::Record
    self.table_name = "heartbeat_user_daily_stats"
    self.primary_key = nil

    class << self
      def seconds_for(user_id:, start_date: nil, end_date: nil)
        relation = where(user_id: user_id)
        relation = relation.where(day: start_date..end_date) if start_date && end_date

        return relation.sum(:seconds).to_f.round unless start_date && end_date

        range_corrected_seconds(relation)
      end

      def first_active_day_for(user_id:, start_date:, end_date:)
        grouped_sql = where(user_id: user_id, day: start_date..end_date)
          .select(Arel.sql("day, sum(heartbeat_count) AS heartbeat_count"))
          .group(:day)
          .to_sql

        value = connection.select_value(<<~SQL.squish)
          SELECT min(day)
          FROM (#{grouped_sql}) AS grouped_days
          WHERE heartbeat_count > 0
        SQL
        value && Date.parse(value.to_s)
      end

      def days_with_heartbeats_for(user_id:, start_date:, end_date:)
        grouped_sql = where(user_id: user_id, day: start_date..end_date)
          .select(Arel.sql("day, sum(heartbeat_count) AS heartbeat_count"))
          .group(:day)
          .to_sql

        connection.select_value(<<~SQL.squish).to_f.round
          SELECT count()
          FROM (#{grouped_sql}) AS grouped_days
          WHERE heartbeat_count > 0
        SQL
      end

      private

      def range_corrected_seconds(relation)
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
    end
  end
end
