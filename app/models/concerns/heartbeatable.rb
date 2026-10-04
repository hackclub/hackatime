module Heartbeatable
  extend ActiveSupport::Concern

  BROWSER_EDITORS = %w[arc brave chrome chromium edge firefox floorp librewolf microsoft-edge opera opera-gx safari vivaldi waterfox zen].freeze

  # Upper bound for a valid heartbeat timestamp (9999-12-31). Times outside
  # [0, MAX_VALID_TIME] come from broken clients and are ignored everywhere.
  MAX_VALID_TIME = 253402300799

  included do
    # Filter heartbeats to only include those with category equal to "coding"
    scope :coding_only, -> { where(category: "coding") }
    scope :excluding_browser_time, -> {
      where("editor IS NULL OR lower(editor) NOT IN (?)", BROWSER_EDITORS)
    }
    scope :leaderboard_eligible, -> {
      coding_only
        .excluding_browser_time
        .where("project IS NULL OR project != ?", "<<LAST_PROJECT>>")
        .with_valid_timestamps
    }

    scope :with_valid_timestamps, -> { where("time >= 0 AND time <= ?", MAX_VALID_TIME) }
  end

  # Duration SQL (ClickHouse).
  #
  # Duration is not stored. Each heartbeat contributes the gap since the
  # previous heartbeat in its partition, capped at the timeout; the first
  # heartbeat in a partition contributes zero. Rows are ordered by (time, id).
  #
  # ClickHouse's lagInFrame returns the type default (0.0) for the first row
  # rather than NULL, so the first row is detected with row_number() instead.
  # Durations are summed as floats and rounded once at the end, matching
  # Postgres's float -> integer cast (halves round to even).
  module DurationSql
    module_function

    # `gap` expression for a window named `w` over `time`.
    def capped_gap(timeout, window: "w")
      "least(if(row_number() OVER #{window} = 1, 0, time - lagInFrame(time) OVER #{window}), #{Integer(timeout)})"
    end

    def window(partition_by = nil)
      partition = partition_by.present? ? "PARTITION BY #{Array(partition_by).join(', ')} " : ""
      "(#{partition}ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)"
    end

    # Integer seconds from a float sum. ClickHouse's round() and Postgres's
    # float8 -> integer cast both round halves to even (2.5 -> 2).
    def to_seconds(expr) = "toInt64(round(#{expr}))"

    # Constant, validated timezone literal.
    def timezone_literal(timezone)
      zone = ActiveSupport::TimeZone[timezone.to_s]&.tzinfo&.name || (TZInfo::Timezone.get(timezone.to_s).name rescue "UTC")
      Heartbeat.connection.quote(zone)
    end

    def local_datetime(timezone, column: "time") = "toDateTime(toInt64(floor(#{column})), #{timezone_literal(timezone)})"
  end

  class_methods do
    def heartbeat_timeout_duration(duration = nil)
      duration ? (@heartbeat_timeout_duration = duration) : (@heartbeat_timeout_duration || 2.minutes)
    end

    def to_span(timeout_duration: nil)
      timeout_duration ||= heartbeat_timeout_duration.to_i

      times = with_valid_timestamps.reorder(time: :asc, id: :asc).pluck(:time)
      return [] if times.empty?

      spans = []
      current_span_start = times.first
      times.each_with_index do |current_time, index|
        next_time = times[index + 1]
        next unless next_time.nil? || (next_time - current_time) > timeout_duration

        base_duration = (current_time - current_span_start).round
        if next_time
          gap_duration = [ next_time - current_time, timeout_duration ].min
          total_duration = base_duration + gap_duration
          end_time = current_time + gap_duration
        else
          total_duration = base_duration
          end_time = current_time
        end

        spans << { start_time: current_span_start, end_time:, duration: total_duration } if total_duration > 0
        current_span_start = next_time if next_time
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

    def streak_cache_keys(user_ids, exclude_browser_time:)
      prefix = exclude_browser_time ? "user_streak_without_browser_v4" : "user_streak_v4"
      versions = HeartbeatExclusion.cache_versions(user_ids)
      user_ids.index_with { |id| "#{prefix}_#{id}_#{versions.fetch(id)}" }
    end

    # Consecutive local days (ending today or yesterday) with at least 15
    # minutes of non-browsing activity. One ClickHouse query per timezone, so
    # local days are always computed with a constant timezone.
    def daily_streaks_for_users(user_ids, start_date: 31.days.ago, exclude_browser_time: false)
      return {} if user_ids.empty?
      start_date = [ start_date, 31.days.ago ].max
      cache_keys = streak_cache_keys(user_ids, exclude_browser_time:)
      streak_cache = Rails.cache.read_multi(*cache_keys.values)

      uncached_users = user_ids.select { |id| streak_cache[cache_keys[id]].nil? }
      result = user_ids.index_with { |id| streak_cache[cache_keys[id]] || 0 }
      return result if uncached_users.empty?

      timezones = User.where(id: uncached_users).pluck(:id, :timezone).to_h
      uncached_users.group_by { |id| valid_timezone(timezones[id]) }.each do |timezone, ids|
        scope = where(user_id: ids).where.not(category: "browsing").with_valid_timestamps
          .where(time: start_date.to_f..Time.current.to_f)
        scope = scope.excluding_browser_time if exclude_browser_time
        local_day = "toDate(#{DurationSql.local_datetime(timezone)})"
        rows = connection.select_rows(<<~SQL.squish)
          SELECT user_id, day, #{DurationSql.to_seconds('sum(gap)')} AS duration
          FROM (
            SELECT user_id, #{local_day} AS day,
                   #{DurationSql.capped_gap(heartbeat_timeout_duration.to_i)} AS gap
            FROM (#{scope.select(:user_id, :time, :id).to_sql}) AS streak_heartbeats
            WINDOW w AS #{DurationSql.window(%W[user_id #{local_day}])}
          )
          GROUP BY user_id, day
        SQL

        current_date = Time.current.in_time_zone(timezone).to_date
        days_by_user = rows.group_by(&:first)
        ids.each do |user_id|
          eligible_days = days_by_user.fetch(user_id, [])
            .filter_map { |_, day, duration| day.to_date if day.to_date <= current_date && duration.to_i >= 15 * 60 }
            .sort.reverse
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
          Rails.cache.write(cache_keys.fetch(user_id), streak, expires_in: 1.hour)
        end
      end

      result
    end

    def daily_durations(user_timezone:, start_date: 365.days.ago, end_date: Time.current)
      timezone = valid_timezone(user_timezone)
      day = "toDate(#{DurationSql.local_datetime(timezone)})"
      relation = with_valid_timestamps.where(time: start_date.to_f..end_date.to_f).unscope(:group, :order, :select)
      connection.select_rows(<<~SQL.squish).map { |date, duration| [ date.to_date, duration.to_i ] }
        SELECT day, #{DurationSql.to_seconds('sum(gap)')}
        FROM (
          SELECT #{day} AS day, #{DurationSql.capped_gap(heartbeat_timeout_duration.to_i)} AS gap
          FROM (#{relation.select(:time, :id).to_sql}) AS daily_heartbeats
          WINDOW w AS #{DurationSql.window(day)}
        )
        GROUP BY day
      SQL
    end

    # Per local day, project and AI model: duration (gap to the next heartbeat
    # on the same local day, capped), AI token sums and counts. The "next"
    # heartbeat is the previous row in descending (time, id) order, so the
    # day's last heartbeat contributes 0. (No SQL `--` comments: the query is
    # squished onto one line.)
    def daily_activity_summary_rows(scope:, timezone:)
      timezone = valid_timezone(timezone)
      timeout = heartbeat_timeout_duration.to_i
      day = "toDate(#{DurationSql.local_datetime(timezone)})"
      summary = scope.with_valid_timestamps.unscope(:group, :order, :select)
        .select(:id, :time, :project, :ai_model, :ai_input_tokens, :ai_output_tokens, :ai_line_changes)
      # Inner columns are renamed (in_*) because ClickHouse resolves an output
      # alias like `AS ai_input_tokens` inside its own aggregate.
      connection.select_all(<<~SQL.squish).to_a
        SELECT local_date,
               project,
               ai_model,
               #{DurationSql.to_seconds('sum(gap)')} AS duration,
               toInt64(ifNull(sum(in_ai_input_tokens), 0)) AS ai_input_tokens,
               toInt64(count(in_ai_input_tokens)) AS ai_input_token_count,
               toInt64(ifNull(sum(in_ai_output_tokens), 0)) AS ai_output_tokens,
               toInt64(count(in_ai_output_tokens)) AS ai_output_token_count,
               toInt64(ifNull(sum(in_ai_line_changes), 0)) AS ai_line_changes
        FROM (
          SELECT #{day} AS local_date, project, ai_model, ai_input_tokens AS in_ai_input_tokens,
                 ai_output_tokens AS in_ai_output_tokens, ai_line_changes AS in_ai_line_changes,
                 least(if(row_number() OVER wd = 1, 0, lagInFrame(time) OVER wd - time), #{timeout}) AS gap
          FROM (#{summary.to_sql}) AS daily_summary_heartbeats
          WINDOW wd AS (PARTITION BY #{day} ORDER BY time DESC, id DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        )
        GROUP BY local_date, project, ai_model
        ORDER BY local_date, project, ai_model
      SQL
    end

    # Global gaps (ordered over the whole scope), attributed to the bucket of
    # the heartbeat that ends each gap. Empty and NULL buckets are dropped.
    def attributed_durations_by(scope, field)
      scope = scope.with_valid_timestamps.unscope(:group, :select, :order)
      column = connection.quote_column_name(field.to_s)
      connection.select_rows(<<~SQL.squish).to_h { |bucket, duration| [ bucket, duration.to_i ] }
        SELECT bucket, #{DurationSql.to_seconds('sum(gap)')}
        FROM (
          SELECT #{column} AS bucket, #{DurationSql.capped_gap(heartbeat_timeout_duration.to_i)} AS gap
          FROM (#{scope.select(:id, :time, field).to_sql}) AS attribution_heartbeats
          WINDOW w AS #{DurationSql.window}
        )
        WHERE bucket IS NOT NULL AND bucket != ''
        GROUP BY bucket
      SQL
    end

    def duration_seconds(scope = all)
      scope = scope.with_valid_timestamps
      timeout = heartbeat_timeout_duration.to_i

      if scope.group_values.any?
        raise NotImplementedError, "Multiple group values are not supported" if scope.group_values.length > 1

        group_column = scope.group_values.first
        # Don't quote if it's a SQL expression (contains parentheses)
        group_expr = group_column.to_s.include?("(") ? group_column.to_s : connection.quote_column_name(group_column)
        inner = scope.unscope(:group, :order, :select).select(Arel.sql("#{group_expr} AS grouped_time"), :time, :id)

        connection.select_rows(<<~SQL.squish).to_h { |group, duration| [ group, duration.to_i ] }
          SELECT grouped_time, #{DurationSql.to_seconds('sum(gap)')}
          FROM (
            SELECT grouped_time, #{DurationSql.capped_gap(timeout)} AS gap
            FROM (#{inner.to_sql}) AS grouped_heartbeats
            WINDOW w AS #{DurationSql.window('grouped_time')}
          )
          GROUP BY grouped_time
        SQL
      else
        inner = scope.unscope(:order, :select).select(:time, :id)
        connection.select_value(<<~SQL.squish).to_i
          SELECT #{DurationSql.to_seconds('ifNull(sum(gap), 0)')}
          FROM (
            SELECT #{DurationSql.capped_gap(timeout)} AS gap
            FROM (#{inner.to_sql}) AS duration_heartbeats
            WINDOW w AS #{DurationSql.window}
          )
        SQL
      end
    end

    # Duration within [start_time, end_time], also counting the gap from the
    # last heartbeat before start_time to the first one inside the range.
    def duration_seconds_boundary_aware(scope, start_time, end_time, excluded_categories: [])
      scope = scope.with_valid_timestamps
      base_scope = scope.model.all.with_valid_timestamps
      base_scope = base_scope.where.not("lower(category) IN (?)", excluded_categories) if excluded_categories.present?

      where_values = scope.where_values_hash
      %w[user_id category project deleted_at].each do |key|
        base_scope = base_scope.where(key => where_values[key]) if where_values[key]
      end

      boundary_time = base_scope.where("time < ?", start_time.to_f).maximum(:time)
      combined_scope = boundary_time ?
        base_scope.where("time >= ? OR time = ?", start_time.to_f, boundary_time).where("time <= ?", end_time.to_f) :
        base_scope.where(time: start_time.to_f..end_time.to_f)

      connection.select_value(<<~SQL.squish).to_i
        SELECT #{DurationSql.to_seconds('ifNull(sum(gap), 0)')}
        FROM (
          SELECT time, #{DurationSql.capped_gap(heartbeat_timeout_duration.to_i)} AS gap
          FROM (#{combined_scope.unscope(:order, :select).select(:time, :id).to_sql}) AS boundary_heartbeats
          WINDOW w AS #{DurationSql.window}
        )
        WHERE time >= #{start_time.to_f}
      SQL
    end

    private

    def valid_timezone(timezone)
      TZInfo::Timezone.get(timezone.to_s).name
    rescue TZInfo::InvalidTimezoneIdentifier, ArgumentError
      Rails.logger.warn "Invalid timezone #{timezone.inspect}; defaulting to UTC."
      "UTC"
    end
  end
end
