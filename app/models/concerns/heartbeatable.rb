module Heartbeatable
  extend ActiveSupport::Concern

  included do
    # Filter heartbeats to only include those with category equal to "coding"
    scope :coding_only, -> { where(category: "coding") }

    # This is to prevent PG timestamp overflow errors if someones gives us a
    # heartbeat with a time that is enormously far in the future.
    scope :with_valid_timestamps, -> { where("time >= 0 AND time <= ?", 253402300799) }
  end

  class_methods do
    def heartbeat_timeout_duration(duration = nil)
      if duration
        @heartbeat_timeout_duration = duration
      else
        @heartbeat_timeout_duration || 2.minutes
      end
    end

    def to_span(timeout_duration: nil)
      timeout_duration ||= heartbeat_timeout_duration.to_i

      heartbeats = with_valid_timestamps.order(time: :asc)
      return [] if heartbeats.empty?

      sql = <<~SQL
        SELECT
          time,
          LEAD(time) OVER (ORDER BY time) as next_time
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
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60
      remaining_seconds = seconds % 60

      format("%02d:%02d:%02d", hours, minutes, remaining_seconds)
    end

    def duration_simple(scope = all)
      # 3 hours 10 min => "3 hrs"
      # 1 hour 10 min => "1 hr"
      # 10 min => "10 min"
      seconds = duration_seconds(scope)
      hours = seconds / 3600
      minutes = (seconds % 3600) / 60

      if hours > 1
        "#{hours} hrs"
      elsif hours == 1
        "1 hr"
      elsif minutes > 0
        "#{minutes} min"
      else
        "0 min"
      end
    end

    def daily_streaks_for_users(user_ids, start_date: 31.days.ago)
      return {} if user_ids.empty?
      start_date = [ start_date, 30.days.ago ].max
      keys = user_ids.map { |id| "user_streak_#{id}" }
      streak_cache = Rails.cache.read_multi(*keys)

      uncached_users = user_ids.select { |id| streak_cache["user_streak_#{id}"].nil? }

      if uncached_users.empty?
        return user_ids.index_with { |id| streak_cache["user_streak_#{id}"] || 0 }
      end

      raw_durations = joins(:user)
        .where(user_id: uncached_users)
        .coding_only
        .with_valid_timestamps
        .where(time: start_date..Time.current)
        .select(
          :user_id,
          "users.timezone as user_timezone",
          Arel.sql("DATE_TRUNC('day', to_timestamp(time) AT TIME ZONE users.timezone) as day_group"),
          Arel.sql("LEAST(EXTRACT(EPOCH FROM (to_timestamp(time) - to_timestamp(LAG(time) OVER (PARTITION BY user_id, DATE_TRUNC('day', to_timestamp(time) AT TIME ZONE users.timezone) ORDER BY time)))), #{heartbeat_timeout_duration.to_i}) as diff")
        )

      # Then aggregate the results
      daily_durations = connection.select_all(
        "SELECT user_id, user_timezone, day_group, COALESCE(SUM(diff), 0)::integer as duration
         FROM (#{raw_durations.to_sql}) AS diffs
         GROUP BY user_id, user_timezone, day_group"
      ).group_by { |row| row["user_id"] }
       .transform_values do |rows|
         timezone = rows.first["user_timezone"]
         current_date = Time.current.in_time_zone(timezone).to_date
         {
           current_date: current_date,
           days: rows.map do |row|
             [ row["day_group"].to_date, row["duration"].to_i ]
           end.sort_by { |date, _| date }.reverse
         }
       end

      result = user_ids.index_with { |id| streak_cache["user_streak_#{id}"] || 0 }

      # Then calculate streaks for each user
      daily_durations.each do |user_id, data|
        current_date = data[:current_date]
        days = data[:days]

        # Calculate streak
        streak = 0
        days.each do |date, duration|
          # Skip if this day is in the future
          next if date > current_date

          # If they didn't code enough today, just skip
          if date == current_date
            next unless duration >= 15 * 60
            streak += 1
            next
          end

          # For previous days, check if it's the next day in the streak
          if date == current_date - streak.days && duration >= 15 * 60
            streak += 1
          else
            break
          end
        end

        result[user_id] = streak

        # Cache the streak for 1 hour
        Rails.cache.write("user_streak_#{user_id}", streak, expires_in: 1.hour)
      end

      result
    end

    def daily_durations(user_timezone:, start_date: 365.days.ago, end_date: Time.current)
      timezone = user_timezone

      unless TZInfo::Timezone.all_identifiers.include?(timezone)
        Rails.logger.warn "Invalid timezone provided to daily_durations: #{timezone}. Defaulting to UTC."
        timezone = "UTC"
      end

      # Create the timezone-aware date truncation expression
      day_trunc = Arel.sql("DATE_TRUNC('day', to_timestamp(time) AT TIME ZONE '#{timezone}')")

      select(day_trunc.as("day_group"))
        .where(time: start_date..end_date)
        .group(day_trunc)
        .duration_seconds
        .map { |date, duration| [ date.to_date, duration ] }
    end

    def duration_seconds(scope = all)
      scope = scope.with_valid_timestamps

      if scope.group_values.any?
        if scope.group_values.length > 1
          raise NotImplementedError, "Multiple group values are not supported"
        end

        group_column = scope.group_values.first

        # Don't quote if it's a SQL function (contains parentheses)
        group_expr = group_column.to_s.include?("(") ? group_column : connection.quote_column_name(group_column)

        capped_diffs = scope
          .select("#{group_expr} as grouped_time, CASE
            WHEN LAG(time) OVER (PARTITION BY #{group_expr} ORDER BY time) IS NULL THEN 0
            ELSE LEAST(EXTRACT(EPOCH FROM (to_timestamp(time) - to_timestamp(LAG(time) OVER (PARTITION BY #{group_expr} ORDER BY time)))), #{heartbeat_timeout_duration.to_i})
          END as diff")
          .where.not(time: nil)
          .unscope(:group)

        connection.select_all(
          "SELECT grouped_time, COALESCE(SUM(diff), 0)::integer as duration
          FROM (#{capped_diffs.to_sql}) AS diffs
          GROUP BY grouped_time"
        ).each_with_object({}) do |row, hash|
          hash[row["grouped_time"]] = row["duration"].to_i
        end
      else
        # when not grouped, return a single value
        capped_diffs = scope
          .select("CASE
            WHEN LAG(time) OVER (ORDER BY time) IS NULL THEN 0
            ELSE LEAST(EXTRACT(EPOCH FROM (to_timestamp(time) - to_timestamp(LAG(time) OVER (ORDER BY time)))), #{heartbeat_timeout_duration.to_i})
          END as diff")
          .where.not(time: nil)

        connection.select_value("SELECT COALESCE(SUM(diff), 0)::integer FROM (#{capped_diffs.to_sql}) AS diffs").to_i
      end
    end

    def duration_seconds_boundary_aware(scope, start_time, end_time)
      scope = scope.with_valid_timestamps

      model_class = scope.model
      base_scope = model_class.all.with_valid_timestamps

      excluded_categories = [ "browsing", "ai coding", "meeting", "communicating" ]
      base_scope = base_scope.where.not("LOWER(category) IN (?)", excluded_categories)

      if scope.where_values_hash["user_id"]
        base_scope = base_scope.where(user_id: scope.where_values_hash["user_id"])
      end

      if scope.where_values_hash["category"]
        base_scope = base_scope.where(category: scope.where_values_hash["category"])
      end

      if scope.where_values_hash["project"]
        base_scope = base_scope.where(project: scope.where_values_hash["project"])
      end

      if scope.where_values_hash["deleted_at"]
        base_scope = base_scope.where(deleted_at: scope.where_values_hash["deleted_at"])
      end

      # get the heartbeat before the start_time
      boundary_heartbeat = base_scope
        .where("time < ?", start_time)
        .order(time: :desc)
        .limit(1)
        .first

      # if it's not NULL, we'll use it
      if boundary_heartbeat
        combined_scope = base_scope
          .where("time >= ? OR time = ?", start_time, boundary_heartbeat.time)
          .where("time <= ?", end_time)
      else
        combined_scope = base_scope
          .where(time: start_time..end_time)
      end

      # we calc w/ the boundary heartbeat, but we only sum within the orignal constraint
      capped_diffs = combined_scope
        .select("time, CASE
          WHEN LAG(time) OVER (ORDER BY time) IS NULL THEN 0
          ELSE LEAST(EXTRACT(EPOCH FROM (to_timestamp(time) - to_timestamp(LAG(time) OVER (ORDER BY time)))), #{heartbeat_timeout_duration.to_i})
        END as diff")
        .where.not(time: nil)
        .order(time: :asc)

      sql = "SELECT COALESCE(SUM(diff), 0)::integer
             FROM (#{capped_diffs.to_sql}) AS diffs
             WHERE time >= #{connection.quote(start_time)}"
      connection.select_value(sql).to_i
    end
  end
end
