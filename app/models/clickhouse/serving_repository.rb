require "clickhouse_native"
require "uri"

module Clickhouse
  class ServingRepository
    NULL_DIMENSION_VALUE = HeartbeatIntervals::NULL_DIMENSION_VALUE

    class << self
      def pool
        settings = connection_settings
        key = [ Process.pid, *settings.values_at(:host, :port, :database, :user, :password, :pool_size) ]

        pools_mutex.synchronize do
          pools[key] ||= ClickhouseNative::Pool.new(
            **settings.slice(:host, :port, :database, :user, :password, :pool_size),
            pool_timeout: 5,
            logger: Rails.logger,
            settings: { readonly: 2 }
          )
        end
      end

      private

      def pools
        @pools ||= {}
      end

      def pools_mutex
        @pools_mutex ||= Mutex.new
      end

      def connection_settings
        config = Clickhouse::Record.connection_db_config.configuration_hash
        uri = connection_uri(config[:url])

        {
          host: ENV["CLICKHOUSE_NATIVE_HOST"].presence || config[:host] || uri&.host || "localhost",
          port: ENV.fetch("CLICKHOUSE_NATIVE_PORT", 9000).to_i,
          database: config[:database].presence || decoded_uri_component(uri&.path&.delete_prefix("/")) || "default",
          user: config[:username].presence || config[:user].presence || decoded_uri_component(uri&.user) || "default",
          password: config[:password].presence || decoded_uri_component(uri&.password) || "",
          pool_size: [ ENV.fetch("CLICKHOUSE_NATIVE_POOL", config[:pool] || 5).to_i, 1 ].max
        }
      end

      def connection_uri(url)
        return if url.blank?

        URI.parse(url.to_s.sub(/\Aclickhouse:/, "http:"))
      end

      def decoded_uri_component(value)
        URI.decode_www_form_component(value) if value.present?
      end
    end

    def initialize(pool: nil)
      @pool = pool || self.class.pool
    end

    def total_seconds(user_id:, date_range:, filters: {})
      table, conditions = total_source(user_id:, filters:)
      conditions.concat(date_conditions(date_range))

      value = if date_range.empty?
        query_value("SELECT sum(seconds) FROM #{table} WHERE #{conditions.join(' AND ')}")
      else
        query_value(corrected_total_sql(table:, conditions:))
      end
      numeric(value)
    end

    def project_seconds(user_id:, project:)
      projects = encoded_projects(project)
      return 0 if projects.empty?

      numeric(query_value(<<~SQL.squish))
        SELECT sum(seconds)
        FROM heartbeat_project_summaries
        WHERE user_id = #{Integer(user_id)} AND project IN (#{projects.map { |value| quote(value) }.join(', ')})
      SQL
    end

    def project_heartbeat_count(user_id:, project:)
      projects = encoded_projects(project)
      return 0 if projects.empty?

      query_value(<<~SQL.squish).to_i
        SELECT sum(heartbeat_count)
        FROM heartbeat_project_summaries
        WHERE user_id = #{Integer(user_id)} AND project IN (#{projects.map { |value| quote(value) }.join(', ')})
      SQL
    end

    def project_durations_for_users(user_ids:)
      ids = Array(user_ids).map { |user_id| Integer(user_id) }.uniq
      return {} if ids.empty?

      rows = query(<<~SQL.squish)
        SELECT user_id, project, sum(seconds) AS seconds
        FROM heartbeat_project_summaries
        WHERE user_id IN (#{ids.join(', ')})
        GROUP BY user_id, project
      SQL

      rows.each_with_object({}) do |row, result|
        user_id = row.fetch(:user_id).to_i
        project = HeartbeatIntervals.decode_project(row.fetch(:project))
        (result[user_id] ||= {})[project] = numeric(row.fetch(:seconds))
      end
    end

    def home_totals
      row = query(<<~SQL.squish).first || {}
        SELECT countIf(duration >= 1) AS users_tracked,
               sumIf(duration, duration >= 1) AS seconds_tracked
        FROM (
          SELECT user_id, sum(seconds) AS duration
          FROM heartbeat_user_daily_stats
          GROUP BY user_id
        ) AS user_durations
      SQL

      {
        users_tracked: row.fetch(:users_tracked, 0).to_i,
        seconds_tracked: row.fetch(:seconds_tracked, 0).to_i
      }
    end

    def project_durations(user_id:, date_range:)
      conditions = [ "user_id = #{Integer(user_id)}", *date_conditions(date_range) ]
      sql = if date_range.empty?
        <<~SQL.squish
          SELECT project, sum(seconds) AS seconds
          FROM heartbeat_project_summaries
          WHERE #{conditions.join(' AND ')}
          GROUP BY project
        SQL
      else
        <<~SQL.squish
          SELECT project, sum(seconds) - argMin(first_seconds, day) AS seconds
          FROM (
            SELECT project, day, sum(seconds) AS seconds, sum(first_seconds) AS first_seconds,
                   sum(heartbeat_count) AS heartbeat_count
            FROM heartbeat_project_daily_stats
            WHERE #{conditions.join(' AND ')}
            GROUP BY project, day
          ) AS grouped_days
          WHERE heartbeat_count > 0
          GROUP BY project
        SQL
      end
      durations(query(sql), :project).to_h do |project, seconds|
        [ HeartbeatIntervals.decode_project(project), seconds ]
      end
    end

    def dimension_durations(user_id:, dimension:, date_range:)
      attribution_durations(
        table: "heartbeat_dimension_attribution_daily_stats",
        conditions: [ "user_id = #{Integer(user_id)}", "dimension = #{quote(dimension)}" ],
        first_day_source: "heartbeat_user_daily_stats",
        first_day_conditions: [ "user_id = #{Integer(user_id)}" ],
        date_range:
      )
    end

    def filter_durations(user_id:, dimension:, date_range:)
      conditions = [
        "user_id = #{Integer(user_id)}",
        "dimension = #{quote(dimension)}",
        *date_conditions(date_range)
      ]
      sql = grouped_filter_sql(conditions:, date_range:)
      durations(query(sql), :value).to_h do |value, seconds|
        [ value == NULL_DIMENSION_VALUE ? nil : value, seconds ]
      end
    end

    def days_with_heartbeats(user_id:, date_range:)
      conditions = [ "user_id = #{Integer(user_id)}", *date_conditions(date_range) ]
      query_value(<<~SQL.squish).to_i
        SELECT count()
        FROM (
          SELECT day, sum(heartbeat_count) AS heartbeat_count
          FROM heartbeat_user_daily_stats
          WHERE #{conditions.join(' AND ')}
          GROUP BY day
        ) AS grouped_days
        WHERE heartbeat_count > 0
      SQL
    end

    def project_dimension_durations(user_id:, project:, dimension:, date_range:)
      attribution_durations(
        table: "heartbeat_project_dimension_daily_stats",
        conditions: [
          "user_id = #{Integer(user_id)}", "project = #{quote(encoded_project(project))}",
          "dimension = #{quote(dimension)}"
        ],
        first_day_source: "heartbeat_project_daily_stats",
        first_day_conditions: [
          "user_id = #{Integer(user_id)}", "project = #{quote(encoded_project(project))}"
        ],
        date_range:
      )
    end

    def project_dimension_value_count(user_id:, project:, dimension:, date_range:)
      conditions = [
        "user_id = #{Integer(user_id)}", "project = #{quote(encoded_project(project))}",
        "dimension = #{quote(dimension)}",
        *date_conditions(date_range)
      ]
      query_value(<<~SQL.squish).to_i
        SELECT count()
        FROM (
          SELECT value, sum(heartbeat_count) AS heartbeat_count
          FROM heartbeat_project_dimension_daily_stats
          WHERE #{conditions.join(' AND ')}
          GROUP BY value
        ) AS grouped_values
        WHERE heartbeat_count > 0
      SQL
    end

    def language_summary(user_id:, date_range:)
      user_conditions = [ "user_id = #{Integer(user_id)}", *date_conditions(date_range) ]
      language_conditions = [
        "user_id = #{Integer(user_id)}", "dimension = 'language'", *date_conditions(date_range)
      ]
      total_sql = if date_range.empty?
        "SELECT 'total' AS kind, '' AS value, sum(seconds) AS seconds " \
          "FROM heartbeat_user_daily_stats WHERE #{user_conditions.join(' AND ')}"
      else
        corrected_total_sql(table: "heartbeat_user_daily_stats", conditions: user_conditions)
          .sub(/\ASELECT /, "SELECT 'total' AS kind, '' AS value, ")
      end
      language_sql = grouped_filter_sql(conditions: language_conditions, date_range:)
        .sub(/\ASELECT value, /, "SELECT 'language' AS kind, value, ")

      rows = query("#{total_sql} UNION ALL #{language_sql}")
      total = rows.find { |row| row[:kind] == "total" }
      {
        total_seconds: numeric(total&.fetch(:seconds, 0)),
        languages: rows.filter_map do |row|
          next if row[:kind] == "total"

          value = row[:value] == NULL_DIMENSION_VALUE ? nil : row[:value]
          [ value, numeric(row[:seconds]) ]
        end.to_h
      }
    end

    def project_stats(user_id:, project:, date_range:, dimensions:, include_total:)
      dimensions = Array(dimensions).map(&:to_s).uniq
      statements = []
      statements << project_total_row_sql(user_id:, project:, date_range:) if include_total
      statements << project_dimension_rows_sql(user_id:, project:, date_range:, dimensions:) if dimensions.any?
      return { total_seconds: 0, dimensions: {} } if statements.empty?

      rows = query(statements.join(" UNION ALL "))
      dimension_rows = rows.reject { |row| row[:kind] == "total" }
      {
        total_seconds: numeric(rows.find { |row| row[:kind] == "total" }&.fetch(:seconds, 0)),
        dimensions: dimension_rows.group_by { |row| row[:kind].to_sym }.transform_values do |group|
          group.to_h do |row|
            [ row[:value], { seconds: numeric(row[:seconds]), heartbeat_count: row[:heartbeat_count].to_i } ]
          end
        end
      }
    end

    private

    attr_reader :pool

    def total_source(user_id:, filters:)
      base = [ "user_id = #{Integer(user_id)}" ]
      return [ "heartbeat_user_daily_stats", base ] if filters.empty?

      if filters.keys == [ :project ]
        project = encoded_project(filters.fetch(:project))
        return [ "heartbeat_project_daily_stats", base << "project = #{quote(project)}" ]
      end

      dimension, value = filters.first
      [
        "heartbeat_dimension_daily_stats",
        base << "dimension = #{quote(dimension)}" << "value = #{quote(value.nil? ? NULL_DIMENSION_VALUE : value)}"
      ]
    end

    def corrected_total_sql(table:, conditions:)
      <<~SQL.squish
        SELECT if(count() = 0, 0, sum(seconds) - argMin(first_seconds, day)) AS seconds
        FROM (
          SELECT day, sum(seconds) AS seconds, sum(first_seconds) AS first_seconds,
                 sum(heartbeat_count) AS heartbeat_count
          FROM #{table}
          WHERE #{conditions.join(' AND ')}
          GROUP BY day
        ) AS grouped_days
        WHERE heartbeat_count > 0
      SQL
    end

    def grouped_filter_sql(conditions:, date_range:)
      return <<~SQL.squish if date_range.empty?
        SELECT value, sum(seconds) AS seconds
        FROM heartbeat_dimension_daily_stats
        WHERE #{conditions.join(' AND ')}
        GROUP BY value
      SQL

      <<~SQL.squish
        SELECT value, sum(seconds) - argMin(first_seconds, day) AS seconds
        FROM (
          SELECT value, day, sum(seconds) AS seconds, sum(first_seconds) AS first_seconds,
                 sum(heartbeat_count) AS heartbeat_count
          FROM heartbeat_dimension_daily_stats
          WHERE #{conditions.join(' AND ')}
          GROUP BY value, day
        ) AS grouped_days
        WHERE heartbeat_count > 0
        GROUP BY value
      SQL
    end

    def attribution_durations(table:, conditions:, first_day_source:, first_day_conditions:, date_range:)
      scoped_conditions = [ *conditions, *date_conditions(date_range) ]
      if date_range.empty?
        return durations(query(<<~SQL.squish), :value)
          SELECT value, sum(seconds) AS seconds
          FROM #{table}
          WHERE #{scoped_conditions.join(' AND ')}
          GROUP BY value
        SQL
      end

      first_day_conditions = [ *first_day_conditions, *date_conditions(date_range) ]
      sql = <<~SQL.squish
        WITH (
          SELECT min(day)
          FROM (
            SELECT day, sum(heartbeat_count) AS heartbeat_count
            FROM #{first_day_source}
            WHERE #{first_day_conditions.join(' AND ')}
            GROUP BY day
          ) AS active_days
          WHERE heartbeat_count > 0
        ) AS first_day
        SELECT value, sum(seconds) - sumIf(first_seconds, day = first_day) AS seconds
        FROM (
          SELECT value, day, sum(seconds) AS seconds, sum(first_seconds) AS first_seconds
          FROM #{table}
          WHERE #{scoped_conditions.join(' AND ')}
          GROUP BY value, day
        ) AS grouped_days
        GROUP BY value
      SQL
      durations(query(sql), :value)
    end

    def project_total_row_sql(user_id:, project:, date_range:)
      conditions = [
        "user_id = #{Integer(user_id)}", "project = #{quote(encoded_project(project))}",
        *date_conditions(date_range)
      ]
      if date_range.empty?
        return <<~SQL.squish
          SELECT 'total' AS kind, '' AS value, sum(seconds) AS seconds,
                 toInt64(sum(heartbeat_count)) AS heartbeat_count
          FROM heartbeat_project_summaries
          WHERE #{conditions.join(' AND ')}
        SQL
      end

      <<~SQL.squish
        SELECT 'total' AS kind, '' AS value,
               if(count() = 0, 0, sum(seconds) - argMin(first_seconds, day)) AS seconds,
               toInt64(sum(daily_heartbeat_count)) AS heartbeat_count
        FROM (
          SELECT day, sum(seconds) AS seconds, sum(first_seconds) AS first_seconds,
                 sum(heartbeat_count) AS daily_heartbeat_count
          FROM heartbeat_project_daily_stats
          WHERE #{conditions.join(' AND ')}
          GROUP BY day
        ) AS grouped_days
        WHERE daily_heartbeat_count > 0
      SQL
    end

    def project_dimension_rows_sql(user_id:, project:, date_range:, dimensions:)
      conditions = [
        "user_id = #{Integer(user_id)}", "project = #{quote(encoded_project(project))}",
        "dimension IN (#{dimensions.map { |dimension| quote(dimension) }.join(', ')})",
        *date_conditions(date_range)
      ]
      if date_range.empty?
        return <<~SQL.squish
          SELECT dimension AS kind, value, sum(seconds) AS seconds,
                 toInt64(sum(heartbeat_count)) AS heartbeat_count
          FROM heartbeat_project_dimension_daily_stats
          WHERE #{conditions.join(' AND ')}
          GROUP BY dimension, value
        SQL
      end

      first_day_conditions = [
        "user_id = #{Integer(user_id)}", "project = #{quote(encoded_project(project))}",
        *date_conditions(date_range)
      ]
      <<~SQL.squish
        WITH (
          SELECT min(day)
          FROM (
            SELECT day, sum(heartbeat_count) AS heartbeat_count
            FROM heartbeat_project_daily_stats
            WHERE #{first_day_conditions.join(' AND ')}
            GROUP BY day
          ) AS active_days
          WHERE heartbeat_count > 0
        ) AS first_day
        SELECT dimension AS kind, value,
               sum(seconds) - sumIf(first_seconds, day = first_day) AS seconds,
               toInt64(sum(heartbeat_count)) AS heartbeat_count
        FROM (
          SELECT dimension, value, day, sum(seconds) AS seconds, sum(first_seconds) AS first_seconds,
                 sum(heartbeat_count) AS heartbeat_count
          FROM heartbeat_project_dimension_daily_stats
          WHERE #{conditions.join(' AND ')}
          GROUP BY dimension, value, day
        ) AS grouped_days
        GROUP BY dimension, value
      SQL
    end

    def date_conditions(date_range)
      return [] if date_range.empty?

      [ "day >= #{quote(date_range.fetch(:start_date))}", "day <= #{quote(date_range.fetch(:end_date))}" ]
    end

    def quote(value)
      string = value.to_s.gsub("\\", "\\\\").gsub("'", "''")
      "'#{string}'"
    end

    def encoded_project(project)
      HeartbeatIntervals.encode_project(project)
    end

    def encoded_projects(projects)
      values = projects.is_a?(Array) ? projects : [ projects ]
      values.map { |project| encoded_project(project) }.uniq
    end

    def query(sql)
      ActiveSupport::Notifications.instrument("sql.clickhouse_serving", sql:) { pool.query(sql) }
    end

    def query_value(sql)
      ActiveSupport::Notifications.instrument("sql.clickhouse_serving", sql:) { pool.query_value(sql) }
    end

    def durations(rows, key)
      rows.to_h { |row| [ row.fetch(key), numeric(row.fetch(:seconds)) ] }
    end

    def numeric(value)
      value.to_f.round
    end
  end
end
