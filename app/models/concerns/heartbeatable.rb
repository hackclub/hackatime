module Heartbeatable
  extend ActiveSupport::Concern

  BROWSER_EDITORS = %w[arc brave chrome chromium edge firefox floorp librewolf microsoft-edge opera opera-gx safari vivaldi waterfox zen].freeze

  included do
    # Filter heartbeats to only include those with category equal to "coding"
    scope :coding_only, -> { where(category: "coding") }
    scope :excluding_browser_time, -> {
      where("editor IS NULL OR LOWER(editor) NOT IN (?)", BROWSER_EDITORS)
    }
    scope :leaderboard_eligible, -> {
      coding_only
        .excluding_browser_time
        .where("project IS DISTINCT FROM ?", "<<LAST_PROJECT>>")
        .with_valid_timestamps
    }

    # This is to prevent PG timestamp overflow errors if someones gives us a
    # heartbeat with a time that is enormously far in the future.
    scope :with_valid_timestamps, -> { where("time >= 0 AND time <= ?", 253402300799) }
  end

  class_methods do
    def heartbeat_timeout_duration(duration = nil)
      duration ? (@heartbeat_timeout_duration = duration) : (@heartbeat_timeout_duration || 2.minutes)
    end

    def to_span(timeout_duration: nil)
      timeout_duration ||= heartbeat_timeout_duration.to_i

      heartbeats = with_valid_timestamps.order(time: :asc, id: :asc)
      return [] if heartbeats.empty?

      sql = <<~SQL
        SELECT
          time,
          LEAD(time) OVER (ORDER BY time, id) as next_time
        FROM (#{heartbeats.to_sql}) AS heartbeats
      SQL

      results = connection.select_all(sql)
      return [] if results.empty?

      spans = []
      current_span_start = results.first["time"]

      results.each do |row|
        current_time = row["time"]
        next_time = row["next_time"]

        if next_time.nil? || (next_time - current_time) > timeout_duration
          base_duration = (current_time - current_span_start).round

          if next_time
            gap_duration = [ next_time - current_time, timeout_duration ].min
            total_duration = base_duration + gap_duration
            end_time = current_time + gap_duration
          else
            total_duration = base_duration
            end_time = current_time
          end

          if total_duration > 0
            spans << {
              start_time: current_span_start,
              end_time: end_time,
              duration: total_duration
            }
          end

          current_span_start = next_time if next_time
        end
      end

      spans
    end

    def duration_formatted(scope = all)
      seconds = duration_seconds(scope)
      format("%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    end

    def duration_simple(scope = all)
      # 3 hours 10 min => "3 hrs" / 1 hour 10 min => "1 hr" / 10 min => "10 min"
      seconds = duration_seconds(scope)
      hours = seconds / 3600
      return "#{hours} hrs" if hours > 1
      return "1 hr" if hours == 1
      "#{(seconds % 3600) / 60} min" # 0 min if minutes is 0
    end

    def daily_streaks_for_users(user_ids, start_date: 31.days.ago, exclude_browser_time: false)
      return {} if user_ids.empty?
      start_date = [ start_date, 31.days.ago ].max
      cache_prefix = exclude_browser_time ? "user_streak_without_browser_v3" : "user_streak_v3"
      streak_cache = Rails.cache.read_multi(*user_ids.map { |id| "#{cache_prefix}_#{id}" })

      uncached_users = user_ids.select { |id| streak_cache["#{cache_prefix}_#{id}"].nil? }
      return user_ids.index_with { |id| streak_cache["#{cache_prefix}_#{id}"] || 0 } if uncached_users.empty?

      timeout = heartbeat_timeout_duration.to_i
      day_group_sql = "DATE_TRUNC('day', to_timestamp(time) AT TIME ZONE users.timezone)"
      streak_diff_sql = <<~SQL.squish
        LEAST(
          time - LAG(time) OVER (PARTITION BY user_id, #{day_group_sql} ORDER BY time, #{quoted_table_name}.id),
          #{timeout}
        ) as diff
      SQL
      raw_durations = joins(:user)
        .where(user_id: uncached_users)
        .where.not(category: "browsing")
        .with_valid_timestamps
        .where(time: start_date..Time.current)
        .select(
          :user_id,
          "users.timezone as user_timezone",
          Arel.sql("#{day_group_sql} as day_group"),
          Arel.sql(streak_diff_sql)
        )
      raw_durations = raw_durations.excluding_browser_time if exclude_browser_time

      # Then aggregate the results
      daily_durations = connection.select_all(
        "SELECT user_id, user_timezone, day_group, COALESCE(SUM(diff), 0)::integer as duration
         FROM (#{raw_durations.to_sql}) AS diffs
         GROUP BY user_id, user_timezone, day_group"
      ).group_by { |row| row["user_id"] }
       .transform_values do |rows|
         timezone = rows.first["user_timezone"]

         if timezone.blank?
           Rails.logger.warn "nil tz, going to utc."
           timezone = "UTC"
         else
           begin
             TZInfo::Timezone.get(timezone)
           rescue TZInfo::InvalidTimezoneIdentifier, ArgumentError
             Rails.logger.warn "Invalid timezone for streak calculation: #{timezone}. Defaulting to UTC."
             timezone = "UTC"
           end
         end

         current_date = Time.current.in_time_zone(timezone).to_date
         {
           current_date: current_date,
           days: rows.map do |row|
             [ row["day_group"].to_date, row["duration"].to_i ]
           end.sort_by { |date, _| date }.reverse
         }
       end

      result = user_ids.index_with { |id| streak_cache["#{cache_prefix}_#{id}"] || 0 }

      # Then calculate streaks for each user
      daily_durations.each do |user_id, data|
        current_date = data[:current_date]
        days = data[:days]

        eligible_days = days.filter_map do |date, duration|
          date if date <= current_date && duration >= 15 * 60
        end

        streak = 0
        expected_date = eligible_days.first == current_date ? current_date : current_date - 1.day

        eligible_days.each do |date|
          if date == expected_date
            streak += 1
            expected_date -= 1.day
          elsif date < expected_date
            break
          end
        end

        result[user_id] = streak

        # Cache the streak for 1 hour
        Rails.cache.write("#{cache_prefix}_#{user_id}", streak, expires_in: 1.hour)
      end

      result
    end

    def daily_durations(user_timezone:, start_date: 365.days.ago, end_date: Time.current)
      timezone = user_timezone
      unless TZInfo::Timezone.all_identifiers.include?(timezone)
        Rails.logger.warn "Invalid timezone provided to daily_durations: #{timezone}. Defaulting to UTC."
        timezone = "UTC"
      end

      day_trunc = Arel.sql("DATE_TRUNC('day', to_timestamp(time) AT TIME ZONE '#{timezone}')")
      select(day_trunc.as("day_group")).where(time: start_date..end_date).group(day_trunc).duration_seconds
        .map { |date, duration| [ date.to_date, duration ] }
    end

    def attributed_durations_by(scope, field)
      scope = scope.with_valid_timestamps
      timeout = heartbeat_timeout_duration.to_i
      field_expr = connection.quote_column_name(field.to_s)
      base_sql = scope.unscope(:group, :select, :order).select(:id, :time, field).to_sql

      sql = <<~SQL.squish
        SELECT bucket, COALESCE(SUM(diff), 0)::integer AS duration
        FROM (
          SELECT #{field_expr} AS bucket,
                 CASE WHEN LAG(time) OVER (ORDER BY time, id) IS NULL THEN 0
                      ELSE LEAST(time - LAG(time) OVER (ORDER BY time, id), #{timeout}) END AS diff
          FROM (#{base_sql}) heartbeats_for_attribution
        ) capped_diffs
        WHERE bucket IS NOT NULL AND bucket <> ''
        GROUP BY bucket
      SQL

      connection.select_all(sql).each_with_object({}) { |row, hash| hash[row["bucket"]] = row["duration"].to_i }
    end

    def duration_seconds(scope = all)
      scope = scope.with_valid_timestamps
      timeout = heartbeat_timeout_duration.to_i

      if scope.group_values.any?
        raise NotImplementedError, "Multiple group values are not supported" if scope.group_values.length > 1

        group_column = scope.group_values.first
        # Don't quote if it's a SQL function (contains parentheses)
        group_expr = group_column.to_s.include?("(") ? group_column : connection.quote_column_name(group_column)

        capped_diffs = scope.select("#{group_expr} as grouped_time, CASE WHEN LAG(time) OVER (PARTITION BY #{group_expr} ORDER BY time, #{quoted_table_name}.id) IS NULL THEN 0 ELSE LEAST(time - LAG(time) OVER (PARTITION BY #{group_expr} ORDER BY time, #{quoted_table_name}.id), #{timeout}) END as diff")
          .where.not(time: nil).unscope(:group)

        connection.select_all(
          "SELECT grouped_time, COALESCE(SUM(diff), 0)::integer as duration FROM (#{capped_diffs.to_sql}) AS diffs GROUP BY grouped_time"
        ).each_with_object({}) { |row, hash| hash[row["grouped_time"]] = row["duration"].to_i }
      else
        # when not grouped, return a single value
        capped_diffs = scope.select("CASE WHEN LAG(time) OVER (ORDER BY time, #{quoted_table_name}.id) IS NULL THEN 0 ELSE LEAST(time - LAG(time) OVER (ORDER BY time, #{quoted_table_name}.id), #{timeout}) END as diff").where.not(time: nil)
        connection.select_value("SELECT COALESCE(SUM(diff), 0)::integer FROM (#{capped_diffs.to_sql}) AS diffs").to_i
      end
    end

    def duration_seconds_boundary_aware(scope, start_time, end_time, excluded_categories: [])
      scope = scope.with_valid_timestamps
      base_scope = scope.model.all.with_valid_timestamps
      base_scope = base_scope.where.not("LOWER(category) IN (?)", excluded_categories) if excluded_categories.present?

      where_values = scope.where_values_hash
      %w[user_id category project deleted_at].each do |key|
        base_scope = base_scope.where(key => where_values[key]) if where_values[key]
      end

      # get the heartbeat before the start_time
      boundary_heartbeat = base_scope.where("time < ?", start_time).order(time: :desc, id: :desc).limit(1).first

      # if it's not NULL, we'll use it
      combined_scope = boundary_heartbeat ?
        base_scope.where("time >= ? OR time = ?", start_time, boundary_heartbeat.time).where("time <= ?", end_time) :
        base_scope.where(time: start_time..end_time)

      # we calc w/ the boundary heartbeat, but we only sum within the orignal constraint
      timeout = heartbeat_timeout_duration.to_i
      capped_diffs = combined_scope
        .select("time, CASE WHEN LAG(time) OVER (ORDER BY time, #{quoted_table_name}.id) IS NULL THEN 0 ELSE LEAST(time - LAG(time) OVER (ORDER BY time, #{quoted_table_name}.id), #{timeout}) END as diff")
        .where.not(time: nil).order(time: :asc, id: :asc)

      connection.select_value("SELECT COALESCE(SUM(diff), 0)::integer FROM (#{capped_diffs.to_sql}) AS diffs WHERE time >= #{connection.quote(start_time)}").to_i
    end
  end
end
