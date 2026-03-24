module Heartbeatable
  extend ActiveSupport::Concern

  included do
    scope :coding_only, -> { where(category: "coding") }
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
          leadInFrame(time) OVER (ORDER BY time ASC ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING) as next_time
        FROM (#{heartbeats.to_sql}) AS heartbeats
      SQL

      results = connection.select_all(sql)
      return [] if results.empty?

      spans = []
      current_span_start = results.first["time"]

      results.each do |row|
        current_time = row["time"]
        next_time = row["next_time"]

        if next_time.nil? || next_time == 0 || (next_time - current_time) > timeout_duration
          base_duration = (current_time - current_span_start).round

          if next_time && next_time != 0
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

          current_span_start = next_time if next_time && next_time != 0
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

      # Fetch user timezones from Postgres
      user_timezones = User.where(id: uncached_users).pluck(:id, :timezone).to_h

      timeout = heartbeat_timeout_duration.to_i

      # Query heartbeats from ClickHouse (no cross-DB join)
      raw_sql = <<~SQL
        SELECT
          user_id,
          toDate(toDateTime(toUInt32(time))) AS day_group,
          toInt64(coalesce(sum(diff), 0)) AS duration
        FROM (
          SELECT
            user_id,
            time,
            least(
              time - lagInFrame(time) OVER (PARTITION BY user_id, toDate(toDateTime(toUInt32(time))) ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW),
              #{timeout}
            ) AS diff
          FROM heartbeats
          WHERE user_id IN (#{uncached_users.join(',')})
            AND category = 'coding'
            AND time >= 0 AND time <= 253402300799
            AND time >= #{start_date.to_f}
            AND time <= #{Time.current.to_f}
        )
        GROUP BY user_id, day_group
      SQL

      rows = connection.select_all(raw_sql)

      daily_durations = rows.group_by { |row| row["user_id"].to_i }
        .transform_values do |user_rows|
          user_rows.map do |row|
            [ row["day_group"].to_date, row["duration"].to_i ]
          end.sort_by { |date, _| date }.reverse
        end

      result = user_ids.index_with { |id| streak_cache["user_streak_#{id}"] || 0 }

      daily_durations.each do |user_id, days|
        timezone = user_timezones[user_id] || "UTC"

        begin
          TZInfo::Timezone.get(timezone)
        rescue TZInfo::InvalidTimezoneIdentifier, ArgumentError
          timezone = "UTC"
        end

        current_date = Time.current.in_time_zone(timezone).to_date

        streak = 0
        days.each do |date, duration|
          next if date > current_date

          if date == current_date
            next unless duration >= 15 * 60
            streak += 1
            next
          end

          if date == current_date - streak.days && duration >= 15 * 60
            streak += 1
          else
            break
          end
        end

        result[user_id] = streak
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

      sql = <<~SQL
        SELECT
          toDate(toDateTime(toUInt32(time), '#{timezone}')) AS day_group,
          toInt64(coalesce(sum(diff), 0)) AS duration
        FROM (
          SELECT
            time,
            least(
              time - lagInFrame(time) OVER (ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW),
              #{heartbeat_timeout_duration.to_i}
            ) AS diff
          FROM (#{with_valid_timestamps.where(time: start_date.to_f..end_date.to_f).to_sql}) AS hb
        )
        GROUP BY day_group
        ORDER BY day_group
      SQL

      connection.select_all(sql).map { |row| [ row["day_group"].to_date, row["duration"].to_i ] }
    end

    def duration_seconds(scope = all)
      scope = scope.with_valid_timestamps
      timeout = heartbeat_timeout_duration.to_i

      if scope.group_values.any?
        if scope.group_values.length > 1
          raise NotImplementedError, "Multiple group values are not supported"
        end

        group_column = scope.group_values.first
        group_expr = group_column.to_s.include?("(") ? group_column : "`#{group_column}`"

        capped_diffs_sql = scope
          .select("#{group_expr} as grouped_time, least(time - lagInFrame(time) OVER (PARTITION BY #{group_expr} ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), #{timeout}) as diff")
          .where.not(time: nil)
          .unscope(:group)
          .to_sql

        connection.select_all(
          "SELECT grouped_time, toInt64(coalesce(sum(diff), 0)) as duration FROM (#{capped_diffs_sql}) GROUP BY grouped_time"
        ).each_with_object({}) do |row, hash|
          hash[row["grouped_time"]] = row["duration"].to_i
        end
      else
        capped_diffs_sql = scope
          .select("least(time - lagInFrame(time) OVER (ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), #{timeout}) as diff")
          .where.not(time: nil)
          .to_sql

        connection.select_value("SELECT toInt64(coalesce(sum(diff), 0)) FROM (#{capped_diffs_sql})").to_i
      end
    end

    def duration_seconds_boundary_aware(scope, start_time, end_time)
      scope = scope.with_valid_timestamps

      model_class = scope.model
      base_scope = model_class.all.with_valid_timestamps

      excluded_categories = [ "browsing", "ai coding", "meeting", "communicating" ]
      base_scope = base_scope.where.not("lower(category) IN (?)", excluded_categories)

      if scope.where_values_hash["user_id"]
        base_scope = base_scope.where(user_id: scope.where_values_hash["user_id"])
      end

      if scope.where_values_hash["category"]
        base_scope = base_scope.where(category: scope.where_values_hash["category"])
      end

      if scope.where_values_hash["project"]
        base_scope = base_scope.where(project: scope.where_values_hash["project"])
      end

      boundary_heartbeat = base_scope
        .where("time < ?", start_time)
        .order(time: :desc)
        .limit(1)
        .first

      if boundary_heartbeat
        combined_scope = base_scope
          .where("time >= ? OR time = ?", start_time, boundary_heartbeat.time)
          .where("time <= ?", end_time)
      else
        combined_scope = base_scope
          .where(time: start_time..end_time)
      end

      timeout = heartbeat_timeout_duration.to_i
      capped_diffs_sql = combined_scope
        .select("time, least(time - lagInFrame(time) OVER (ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), #{timeout}) as diff")
        .where.not(time: nil)
        .order(time: :asc)
        .to_sql

      sql = "SELECT toInt64(coalesce(sum(diff), 0)) FROM (#{capped_diffs_sql}) WHERE time >= #{connection.quote(start_time)}"
      connection.select_value(sql).to_i
    end
  end
end
