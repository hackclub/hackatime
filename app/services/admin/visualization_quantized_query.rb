module Admin
  class VisualizationQuantizedQuery
    Result = Struct.new(:success?, :days, :error, keyword_init: true)

    def initialize(user:, year:, month:, connection: ActiveRecord::Base.connection)
      @user = user
      @year = year.to_i
      @month = month.to_i
      @connection = connection
    end

    def call
      return Result.new(success?: false, error: :invalid_parameters) unless valid_month?

      start_epoch, end_epoch = month_range
      quantized_rows = execute_query(quantized_sql, @user.id, start_epoch, end_epoch)
      daily_total_rows = execute_query(daily_totals_sql, @user.id, start_epoch, end_epoch)

      daily_totals = build_daily_totals(daily_total_rows)
      points_by_day = build_points_by_day(quantized_rows)

      Result.new(
        success?: true,
        days: build_days(start_epoch, end_epoch, daily_totals, points_by_day)
      )
    rescue Date::Error, ArgumentError
      Result.new(success?: false, error: :invalid_date)
    end

    private

    def valid_month?
      @month.between?(1, 12)
    end

    def month_range
      start_epoch = Time.utc(@year, @month, 1).to_i
      end_epoch = if @month == 12
        Time.utc(@year + 1, 1, 1).to_i
      else
        Time.utc(@year, @month + 1, 1).to_i
      end

      [ start_epoch, end_epoch ]
    end

    def execute_query(sql, *binds)
      @connection.exec_query(
        ActiveRecord::Base.sanitize_sql([ sql, *binds ])
      )
    end

    def build_daily_totals(rows)
      rows.each_with_object({}) do |row, hash|
        hash[row["day"]] = row["total_seconds"]
      end
    end

    def build_points_by_day(rows)
      rows.each_with_object({}) do |row, hash|
        day = Time.at(row["time"].to_f).utc.to_date
        hash[day] ||= []
        hash[day] << {
          time: row["time"],
          lineno: row["lineno"],
          cursorpos: row["cursorpos"]
        }
      end
    end

    def build_days(start_epoch, end_epoch, daily_totals, points_by_day)
      (start_epoch...end_epoch).step(86_400).map do |epoch|
        day = Time.at(epoch).utc.to_date
        {
          date_timestamp_s: epoch,
          total_seconds: daily_totals[day] || 0,
          points: points_by_day[day] || []
        }
      end
    end

    def quantized_sql
      <<~SQL
        WITH base_heartbeats AS (
            SELECT
                "time",
                lineno,
                cursorpos,
                date_trunc('day', to_timestamp("time")) as day_start
            FROM heartbeats
            WHERE user_id = ?
            AND "time" >= ? AND "time" < ?
            ORDER BY "time" ASC
            LIMIT 1000000
        ),
        daily_stats AS (
            SELECT
                *,
                GREATEST(1, MAX(lineno) OVER (PARTITION BY day_start)) as max_lineno,
                GREATEST(1, MAX(cursorpos) OVER (PARTITION BY day_start)) as max_cursorpos
            FROM base_heartbeats
        ),
        quantized_heartbeats AS (
            SELECT
                *,
                ROUND(2 + (("time" - extract(epoch from day_start)) / 86400) * (396)) as qx,
                ROUND(2 + (1 - CAST(lineno AS decimal) / max_lineno) * (96)) as qy_lineno,
                ROUND(2 + (1 - CAST(cursorpos AS decimal) / max_cursorpos) * (96)) as qy_cursorpos
            FROM daily_stats
        )
        SELECT "time", lineno, cursorpos
        FROM (
            SELECT DISTINCT ON (day_start, qx, qy_lineno) "time", lineno, cursorpos
            FROM quantized_heartbeats
            WHERE lineno IS NOT NULL
            ORDER BY day_start, qx, qy_lineno, "time" ASC
        ) AS lineno_pixels
        UNION
        SELECT "time", lineno, cursorpos
        FROM (
            SELECT DISTINCT ON (day_start, qx, qy_cursorpos) "time", lineno, cursorpos
            FROM quantized_heartbeats
            WHERE cursorpos IS NOT NULL
            ORDER BY day_start, qx, qy_cursorpos, "time" ASC
        ) AS cursorpos_pixels
        UNION
        SELECT "time", lineno, cursorpos
        FROM (
            SELECT DISTINCT ON (day_start, qx) "time", lineno, cursorpos
            FROM quantized_heartbeats
            WHERE lineno IS NULL AND cursorpos IS NULL
            ORDER BY day_start, qx, "time" ASC
        ) AS null_pixels
        ORDER BY "time" ASC
      SQL
    end

    def daily_totals_sql
      <<~SQL
        WITH heartbeats_with_gaps AS (
          SELECT
            date_trunc('day', to_timestamp("time"))::date as day,
            "time" - LAG("time", 1, "time") OVER (PARTITION BY date_trunc('day', to_timestamp("time")) ORDER BY "time") as gap
          FROM heartbeats
          WHERE user_id = ? AND time >= ? AND time < ?
        )
        SELECT
          day,
          SUM(LEAST(gap, 120)) as total_seconds
        FROM heartbeats_with_gaps
        WHERE gap IS NOT NULL
        GROUP BY day
      SQL
    end
  end
end
