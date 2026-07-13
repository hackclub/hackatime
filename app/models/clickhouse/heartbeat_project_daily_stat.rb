module Clickhouse
  class HeartbeatProjectDailyStat < Clickhouse::Record
    self.table_name = "heartbeat_project_daily_stats"
    self.primary_key = nil

    class << self
      def seconds_for(user_id:, project:, start_date: nil, end_date: nil)
        relation = where(user_id: user_id, project: Array(project).map(&:to_s))
        relation = relation.where(day: start_date..end_date) if start_date && end_date

        return relation.sum(:seconds).to_f.round unless start_date && end_date

        range_corrected_seconds(relation)
      end

      def durations_for(user_id:, start_date: nil, end_date: nil)
        relation = where(user_id: user_id)
        relation = relation.where(day: start_date..end_date) if start_date && end_date

        unless start_date && end_date
          return relation.group(:project).sum(:seconds).transform_values { |seconds| seconds.to_f.round }
        end

        range_corrected_durations(relation)
      end

      def first_active_day_for(user_id:, project:, start_date:, end_date:)
        relation = where(user_id: user_id, project: project.to_s, day: start_date..end_date)
        grouped_sql = relation
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

      private

      def range_corrected_seconds(relation)
        rows = grouped_daily_rows(relation, :day)
        return 0 if rows.empty?

        rows.sort_by! { |row| Date.parse(row["day"].to_s) }
        (rows.sum { |row| row["seconds"].to_f } - rows.first["first_seconds"].to_f).round
      end

      def range_corrected_durations(relation)
        grouped_daily_rows(relation, :project, :day)
          .group_by { |row| row["project"] }
          .transform_values do |rows|
            rows.sort_by! { |row| Date.parse(row["day"].to_s) }
            (rows.sum { |row| row["seconds"].to_f } - rows.first["first_seconds"].to_f).round
          end
      end

      def grouped_daily_rows(relation, *groups)
        select_columns = groups.join(", ")
        sql = relation
          .select(Arel.sql("#{select_columns}, sum(seconds) AS seconds, sum(first_seconds) AS first_seconds, sum(heartbeat_count) AS heartbeat_count"))
          .group(*groups)
          .order(*groups)
          .to_sql

        connection.select_all("SELECT * FROM (#{sql}) AS grouped_rows WHERE heartbeat_count > 0").to_a
      end
    end
  end
end
