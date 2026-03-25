module Heartbeatable
  extend ActiveSupport::Concern

  MAX_VALID_TIMESTAMP = 253402300799
  VALID_TIMESTAMPS_SQL = "(time >= 0 AND time <= ?)".freeze

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

      # Fetch user timezones from Postgres, validate once upfront
      raw_timezones = User.where(id: uncached_users).pluck(:id, :timezone).to_h
      user_timezones = raw_timezones.transform_values do |tz|
        begin
          TZInfo::Timezone.get(tz) && tz
        rescue TZInfo::InvalidTimezoneIdentifier, ArgumentError
          "UTC"
        end
      end

      timeout = heartbeat_timeout_duration.to_i

      # Fetch ordered heartbeats once, then bucket by each user's local day in Ruby so
      # diffs do not bleed across midnight in that user's timezone.
      raw_sql = <<~SQL
        SELECT
          user_id,
          time
        FROM heartbeats
        WHERE user_id IN (#{uncached_users.join(',')})
          AND category = 'coding'
          AND time >= 0 AND time <= 253402300799
          AND time >= #{start_date.to_f}
          AND time <= #{Time.current.to_f}
        ORDER BY user_id ASC, time ASC
      SQL

      rows = connection.select_all(raw_sql)

      daily_durations = rows.group_by { |row| row["user_id"].to_i }.transform_values do |user_rows|
        user_id = user_rows.first["user_id"].to_i
        timezone = user_timezones[user_id] || "UTC"

        durations_by_day = Hash.new(0)
        previous_time = nil
        previous_day = nil

        user_rows.each do |row|
          current_time = row["time"].to_f
          current_day = Time.at(current_time).in_time_zone(timezone).to_date

          if previous_time && previous_day == current_day
            gap = current_time - previous_time
            durations_by_day[current_day] += [ [ gap, timeout ].min, 0 ].max.to_i
          end

          previous_time = current_time
          previous_day = current_day
        end

        durations_by_day.sort_by { |date, _| date }.reverse
      end

      result = user_ids.index_with { |id| streak_cache["user_streak_#{id}"] || 0 }

      daily_durations.each do |user_id, days|
        timezone = user_timezones[user_id] || "UTC"
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
          day_group,
          toInt64(coalesce(sum(diff), 0)) AS duration
        FROM (
          SELECT
            toDate(toDateTime(toUInt32(time), '#{timezone}')) AS day_group,
            least(
              greatest(
                time - lagInFrame(time, 1, time) OVER (
                  PARTITION BY toDate(toDateTime(toUInt32(time), '#{timezone}'))
                  ORDER BY time ASC
                  ROWS BETWEEN 1 PRECEDING AND CURRENT ROW
                ),
                0
              ),
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
          .select("#{group_expr} as grouped_time, least(greatest(time - lagInFrame(time, 1, time) OVER (PARTITION BY #{group_expr} ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), 0), #{timeout}) as diff")
          .where.not(time: nil)
          .unscope(:group)
          .to_sql

        connection.select_all(
          "SELECT grouped_time, toInt64(coalesce(sum(diff), 0)) as duration FROM (#{capped_diffs_sql}) GROUP BY grouped_time"
        ).each_with_object({}) do |row, hash|
          hash[row["grouped_time"]] = row["duration"].to_i
        end
      else
        summarized_duration = duration_seconds_from_daily_summary(scope, timeout:)
        return summarized_duration unless summarized_duration.nil?

        raw_duration_seconds(scope, timeout:)
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
        .select("time, least(greatest(time - lagInFrame(time, 1, time) OVER (ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), 0), #{timeout}) as diff")
        .where.not(time: nil)
        .order(time: :asc)
        .to_sql

      sql = "SELECT toInt64(coalesce(sum(diff), 0)) FROM (#{capped_diffs_sql}) WHERE time >= #{connection.quote(start_time)}"
      connection.select_value(sql).to_i
    end

    private

    def duration_seconds_from_daily_summary(scope, timeout:)
      compatibility = summary_compatible_scope(scope)
      return if compatibility.nil?

      day_bounds = summarized_day_bounds(scope)
      return 0 if day_bounds.empty?

      stale_days = [ Time.current.utc.to_date ]
      last_refresh_time = HeartbeatUserDailySummary.last_refresh_time
      stale_days.concat(stale_summary_days(scope, last_refresh_time)) if last_refresh_time.present?

      summary_days = day_bounds
        .map { |row| row["day"].to_date }
        .uniq
        .select { |day| full_day_included?(day, compatibility) && !stale_days.include?(day) }

      raw_days = day_bounds
        .map { |row| row["day"].to_date }
        .uniq - summary_days

      summary_total = HeartbeatUserDailySummary.duration_for_days(
        user_id: compatibility[:user_id],
        days: summary_days
      )

      raw_total = raw_days.sum do |day|
        raw_duration_seconds(scope.where(time: utc_day_range(day)), timeout:)
      end

      summary_total + raw_total + cross_day_bonus(day_bounds, timeout:)
    end

    def summary_compatible_scope(scope)
      return unless scope.model == Heartbeat
      return unless scope.group_values.empty?
      return unless scope.having_clause.empty?
      return unless scope.limit_value.nil? && scope.offset_value.nil?

      compatibility = {
        user_id: nil,
        start_time: nil,
        start_inclusive: true,
        end_time: nil,
        end_inclusive: true
      }

      predicates = scope.where_clause.send(:predicates)

      predicates.each do |predicate|
        return unless apply_summary_predicate(predicate, compatibility)
      end

      return if compatibility[:user_id].blank?

      compatibility
    end

    def apply_summary_predicate(predicate, compatibility)
      case predicate
      when Arel::Nodes::Equality
        apply_summary_equality_predicate(predicate, compatibility)
      when Arel::Nodes::Between
        apply_summary_between_predicate(predicate, compatibility)
      when Arel::Nodes::And
        predicate.children.all? { |child| apply_summary_predicate(child, compatibility) }
      when Arel::Nodes::GreaterThanOrEqual
        apply_summary_lower_bound(predicate, compatibility, inclusive: true)
      when Arel::Nodes::GreaterThan
        apply_summary_lower_bound(predicate, compatibility, inclusive: false)
      when Arel::Nodes::LessThanOrEqual
        apply_summary_upper_bound(predicate, compatibility, inclusive: true)
      when Arel::Nodes::LessThan
        apply_summary_upper_bound(predicate, compatibility, inclusive: false)
      when Arel::Nodes::BoundSqlLiteral
        predicate.sql_with_placeholders == VALID_TIMESTAMPS_SQL &&
          predicate.positional_binds.map { |bind| node_value(bind) } == [ MAX_VALID_TIMESTAMP ]
      else
        false
      end
    end

    def apply_summary_equality_predicate(predicate, compatibility)
      return false unless predicate.left.name.to_s == "user_id"

      user_id = node_value(predicate.right).to_i
      return false if compatibility[:user_id].present? && compatibility[:user_id] != user_id

      compatibility[:user_id] = user_id
      true
    end

    def apply_summary_between_predicate(predicate, compatibility)
      return false unless predicate.left.name.to_s == "time"

      lower_bound, upper_bound = predicate.right.children
      apply_time_lower_bound(compatibility, node_value(lower_bound).to_f, inclusive: true)
      apply_time_upper_bound(compatibility, node_value(upper_bound).to_f, inclusive: true)
      true
    end

    def apply_summary_lower_bound(predicate, compatibility, inclusive:)
      return false unless predicate.left.name.to_s == "time"

      apply_time_lower_bound(compatibility, node_value(predicate.right).to_f, inclusive:)
      true
    end

    def apply_summary_upper_bound(predicate, compatibility, inclusive:)
      return false unless predicate.left.name.to_s == "time"

      apply_time_upper_bound(compatibility, node_value(predicate.right).to_f, inclusive:)
      true
    end

    def apply_time_lower_bound(compatibility, candidate_time, inclusive:)
      current_time = compatibility[:start_time]
      current_inclusive = compatibility[:start_inclusive]

      if current_time.nil? || candidate_time > current_time || (candidate_time == current_time && !inclusive && current_inclusive)
        compatibility[:start_time] = candidate_time
        compatibility[:start_inclusive] = inclusive
      end
    end

    def apply_time_upper_bound(compatibility, candidate_time, inclusive:)
      current_time = compatibility[:end_time]
      current_inclusive = compatibility[:end_inclusive]

      if current_time.nil? || candidate_time < current_time || (candidate_time == current_time && !inclusive && current_inclusive)
        compatibility[:end_time] = candidate_time
        compatibility[:end_inclusive] = inclusive
      end
    end

    def summarized_day_bounds(scope)
      scoped_sql = scope
        .where.not(time: nil)
        .unscope(:order)
        .reselect(:time)
        .to_sql

      connection.select_all(<<~SQL)
        SELECT
          toDate(toDateTime(toUInt32(time))) AS day,
          min(time) AS first_time,
          max(time) AS last_time
        FROM (#{scoped_sql}) AS hb
        GROUP BY day
        ORDER BY day
      SQL
    end

    def stale_summary_days(scope, last_refresh_time)
      scoped_sql = scope
        .where.not(time: nil)
        .unscope(:order)
        .reselect(:time, :updated_at)
        .to_sql

      connection.select_values(<<~SQL).map(&:to_date)
        SELECT DISTINCT toDate(toDateTime(toUInt32(time))) AS day
        FROM (#{scoped_sql}) AS hb
        WHERE updated_at > #{connection.quote(last_refresh_time)}
      SQL
    end

    def full_day_included?(day, compatibility)
      day_start = utc_day_start(day)
      day_end = utc_day_end(day)

      lower_bound_matches = compatibility[:start_time].nil? ||
        compatibility[:start_time] < day_start ||
        (compatibility[:start_time] == day_start && compatibility[:start_inclusive])

      upper_bound_matches = compatibility[:end_time].nil? ||
        compatibility[:end_time] > day_end ||
        (compatibility[:end_time] == day_end && compatibility[:end_inclusive])

      lower_bound_matches && upper_bound_matches
    end

    def cross_day_bonus(day_bounds, timeout:)
      day_bounds.each_cons(2).sum do |previous_day, current_day|
        previous_date = previous_day["day"].to_date
        current_date = current_day["day"].to_date
        next 0 unless current_date == previous_date + 1.day

        gap = current_day["first_time"].to_f - previous_day["last_time"].to_f
        [ [ gap, timeout ].min, 0 ].max.to_i
      end
    end

    def raw_duration_seconds(scope, timeout:)
      capped_diffs_sql = scope
        .select("least(greatest(time - lagInFrame(time, 1, time) OVER (ORDER BY time ASC ROWS BETWEEN 1 PRECEDING AND CURRENT ROW), 0), #{timeout}) as diff")
        .where.not(time: nil)
        .to_sql

      connection.select_value("SELECT toInt64(coalesce(sum(diff), 0)) FROM (#{capped_diffs_sql})").to_i
    end

    def utc_day_range(day)
      utc_day_start(day)..utc_day_end(day)
    end

    def utc_day_start(day)
      day.to_time(:utc).beginning_of_day.to_f
    end

    def utc_day_end(day)
      day.to_time(:utc).end_of_day.to_f
    end

    def node_value(node)
      return node.value_for_database if node.respond_to?(:value_for_database)
      return node.value if node.respond_to?(:value)

      node
    end
  end
end
