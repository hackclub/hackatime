module Clickhouse
  class Heartbeat < Clickhouse::Record
    include TimeRangeFilterable

    self.table_name = "heartbeats"
    self.inheritance_column = nil
    # The gem infers a composite primary key from the ORDER BY tuple, which
    # hijacks #id; the table carries the real Postgres id column.
    self.primary_key = "id"

    BROWSER_EDITORS = %w[arc brave chrome chromium edge firefox floorp librewolf microsoft-edge opera opera-gx safari vivaldi waterfox zen].freeze

    SOURCE_TYPES = ActiveSupport::HashWithIndifferentAccess.new(
      "direct_entry" => 0,
      "wakapi_import" => 1,
      "test_entry" => 2
    ).freeze

    # Keys ordered to match the historical Postgres attributes-hash order so
    # fields_hash stays stable across the PG -> ClickHouse write cutover.
    FIELDS_HASH_KEY_ORDER = %w[
      branch category cursorpos dependencies editor entity is_write language
      line_additions line_deletions lineno lines machine operating_system
      project project_root_count time type user_agent user_id
    ].freeze

    INTEGER_HASH_KEYS = %w[cursorpos line_additions line_deletions lineno lines project_root_count user_id].freeze
    STRING_HASH_KEYS = %w[branch category editor entity language machine operating_system project type user_agent].freeze

    default_scope { final.where(deleted_at: nil) }

    time_range_filterable_field :time

    scope :coding_only, -> { where(category: "coding") }
    scope :excluding_browser_time, -> { where("editor IS NULL OR lower(editor) NOT IN (?)", BROWSER_EDITORS) }
    scope :with_valid_timestamps, -> { where("time >= 0 AND time <= ?", 253402300799) }
    scope :leaderboard_eligible, -> { coding_only.excluding_browser_time.with_valid_timestamps }

    scope :today, -> { where(time: Time.current.beginning_of_day.to_i..Time.current.end_of_day.to_i) }
    scope :recent, -> { where("time > ?", 24.hours.ago.to_i) }
    scope :for_user, ->(user) { where(user_id: user.respond_to?(:id) ? user.id : user) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }

    class << self
      def heartbeat_timeout_duration(duration = nil)
        duration ? (@heartbeat_timeout_duration = duration) : (@heartbeat_timeout_duration || 2.minutes)
      end

      def source_types = SOURCE_TYPES

      def indexed_attributes = FIELDS_HASH_KEY_ORDER

      def generate_fields_hash(attributes)
        attrs = attributes.transform_keys(&:to_s)
        normalized = FIELDS_HASH_KEY_ORDER.index_with { |key| cast_fields_hash_value(key, attrs[key]) }
        Digest::MD5.hexdigest(normalized.to_json)
      end

      def recent_count = Cache::HeartbeatCountsJob.perform_now[:recent_count]
      def recent_imported_count = Cache::HeartbeatCountsJob.perform_now[:recent_imported_count]

      def safe_exists?(scope = all)
        inner = scope.unscope(:select, :order).select(Arel.sql("1 AS one")).limit(1).to_sql
        connection.select_all("SELECT one FROM (#{inner}) AS existence_check LIMIT 1").any?
      rescue ActiveRecord::ActiveRecordError => e
        raise unless e.message.include?("undefined method 'map' for nil")

        false
      end

      def duration_seconds(scope = all)
        scope = scope.with_valid_timestamps
        timeout = heartbeat_timeout_duration.to_i

        if scope.group_values.any?
          raise NotImplementedError, "Multiple group values are not supported" if scope.group_values.length > 1

          group_column = scope.group_values.first
          group_expr = group_column.to_s.include?("(") ? group_column.to_s : connection.quote_column_name(group_column)
          inner = deduped(scope).unscope(:group)
            .select(Arel.sql("#{group_expr} AS grouped_time, #{capped_diff_sql(timeout, group_expr)} AS diff"))
            .to_sql

          connection.select_all("SELECT grouped_time, SUM(diff) AS duration FROM (#{inner}) AS diffs GROUP BY grouped_time")
            .each_with_object({}) { |row, hash| hash[row["grouped_time"]] = row["duration"].to_f.round }
        else
          inner = deduped(scope).select(Arel.sql("#{capped_diff_sql(timeout)} AS diff")).to_sql
          connection.select_all("SELECT SUM(diff) AS duration FROM (#{inner}) AS diffs").first["duration"].to_f.round
        end
      rescue ActiveRecord::ActiveRecordError => e
        raise unless e.message.include?("undefined method 'map' for nil")

        scope.group_values.any? ? {} : 0
      end

      def duration_seconds_boundary_aware(scope, start_time, end_time, excluded_categories: [])
        timeout = heartbeat_timeout_duration.to_i
        start_f = to_epoch(start_time)
        end_f = to_epoch(end_time)

        base = with_valid_timestamps
        base = base.where("lower(category) NOT IN (?)", excluded_categories) if excluded_categories.present?

        where_values = scope.where_values_hash
        %w[user_id category project].each do |key|
          base = base.where(key => where_values[key]) if where_values[key]
        end

        boundary_time = deduped(base).where("time < ?", start_f).order(time: :desc, id: :desc).limit(1).pick(:time)

        combined = if boundary_time
          deduped(base).where("time >= ? OR time = ?", start_f, boundary_time).where("time <= ?", end_f)
        else
          deduped(base).where(time: start_f..end_f)
        end

        inner = combined.select(Arel.sql("time, #{capped_diff_sql(timeout)} AS diff")).to_sql
        connection.select_value("SELECT SUM(diff) FROM (#{inner}) AS diffs WHERE time >= #{start_f.to_f}").to_f.round
      end

      def duration_formatted(scope = all)
        seconds = duration_seconds(scope)
        format("%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
      end

      def duration_simple(scope = all)
        seconds = duration_seconds(scope)
        hours = seconds / 3600
        return "#{hours} hrs" if hours > 1
        return "1 hr" if hours == 1

        "#{(seconds % 3600) / 60} min"
      end

      def daily_durations(user_timezone:, start_date: 365.days.ago, end_date: Time.current)
        timeout = heartbeat_timeout_duration.to_i
        day_expr = day_group_sql(user_timezone)

        inner = deduped(with_valid_timestamps.where(time: start_date..end_date))
          .select(Arel.sql("#{day_expr} AS day_group, #{capped_diff_sql(timeout, day_expr)} AS diff"))
          .to_sql

        connection.select_all("SELECT day_group, SUM(diff) AS duration FROM (#{inner}) AS diffs GROUP BY day_group ORDER BY day_group")
          .map { |row| [ Date.parse(row["day_group"].to_s), row["duration"].to_f.round ] }
      rescue ActiveRecord::ActiveRecordError => e
        raise unless e.message.include?("undefined method 'map' for nil")

        []
      end

      def attributed_durations_by(scope, field)
        scope = scope.with_valid_timestamps
        timeout = heartbeat_timeout_duration.to_i
        field_expr = connection.quote_column_name(field.to_s)

        inner = deduped(scope).unscope(:group, :select, :order)
          .select(Arel.sql("#{field_expr} AS bucket, #{capped_diff_sql(timeout)} AS diff"))
          .to_sql

        connection.select_all(<<~SQL.squish)
          SELECT bucket, SUM(diff) AS duration
          FROM (#{inner}) AS diffs
          WHERE bucket IS NOT NULL AND bucket <> ''
          GROUP BY bucket
        SQL
          .each_with_object({}) { |row, hash| hash[row["bucket"]] = row["duration"].to_f.round }
      end

      def to_span(timeout_duration: nil)
        timeout = (timeout_duration || heartbeat_timeout_duration.to_i).to_i
        times = deduped(with_valid_timestamps).order(:time).pluck(:time)
        return [] if times.empty?

        spans = []
        current_span_start = times.first

        times.each_with_index do |current_time, index|
          next_time = times[index + 1]
          next unless next_time.nil? || (next_time - current_time) > timeout

          base_duration = (current_time - current_span_start).round
          if next_time
            gap_duration = [ next_time - current_time, timeout ].min
            total_duration = base_duration + gap_duration
            end_time = current_time + gap_duration
          else
            total_duration = base_duration
            end_time = current_time
          end

          spans << { start_time: current_span_start, end_time: end_time, duration: total_duration } if total_duration > 0
          current_span_start = next_time if next_time
        end

        spans
      end

      def project_durations_for_users(user_ids)
        return {} if user_ids.empty?

        timeout = heartbeat_timeout_duration.to_i
        diff_sql = "least(" \
          "time - lagInFrame(time, 1, time) OVER (" \
          "PARTITION BY user_id, project ORDER BY time, id " \
          "ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), " \
          "#{timeout})"
        inner = deduped(with_valid_timestamps.where(user_id: user_ids))
          .select(Arel.sql("user_id, project, #{diff_sql} AS diff"))
          .to_sql

        rows = connection.select_all(<<~SQL.squish)
          SELECT user_id, project, SUM(diff) AS duration
          FROM (#{inner}) AS diffs
          GROUP BY user_id, project
        SQL

        rows.each_with_object({}) do |row, result|
          (result[row["user_id"].to_i] ||= {})[row["project"]] = row["duration"].to_f.round
        end
      end

      def daily_streaks_for_users(user_ids, start_date: 31.days.ago, exclude_browser_time: false)
        return {} if user_ids.empty?
        start_date = [ start_date, 31.days.ago ].max
        cache_prefix = exclude_browser_time ? "user_streak_without_browser_v3" : "user_streak_v3"
        streak_cache = Rails.cache.read_multi(*user_ids.map { |id| "#{cache_prefix}_#{id}" })

        uncached_users = user_ids.select { |id| streak_cache["#{cache_prefix}_#{id}"].nil? }
        return user_ids.index_with { |id| streak_cache["#{cache_prefix}_#{id}"] || 0 } if uncached_users.empty?

        timeout = heartbeat_timeout_duration.to_i
        tz_by_user = ::User.where(id: uncached_users).pluck(:id, :timezone).to_h
        users_by_tz = uncached_users.group_by { |id| resolve_timezone(tz_by_user[id]) }

        daily_durations = {}
        users_by_tz.each do |timezone, ids|
          day_expr = day_group_sql(timezone)
          scope = with_valid_timestamps
            .where(user_id: ids)
            .where.not(category: "browsing")
            .where(time: start_date..Time.current)
          scope = scope.excluding_browser_time if exclude_browser_time

          partition = "user_id, #{day_expr}"
          # PG quirk preserved: LEAST(NULL, timeout) = timeout, so the first row
          # of each (user, day) contributes the full timeout, not 0.
          diff_sql = "least(" \
            "time - lagInFrame(time, 1, time - #{timeout}) OVER (" \
            "PARTITION BY #{partition} ORDER BY time, id " \
            "ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), " \
            "#{timeout})"
          inner = deduped(scope)
            .select(Arel.sql("user_id, #{day_expr} AS day_group, #{diff_sql} AS diff"))
            .to_sql

          rows = connection.select_all(<<~SQL.squish)
            SELECT user_id, day_group, SUM(diff) AS duration
            FROM (#{inner}) AS diffs
            GROUP BY user_id, day_group
          SQL
        rescue ActiveRecord::ActiveRecordError => e
          raise unless e.message.include?("undefined method 'map' for nil")

          rows = []
        ensure
          rows ||= []

          current_date = Time.current.in_time_zone(timezone).to_date
          rows.group_by { |row| row["user_id"].to_i }.each do |user_id, user_rows|
            daily_durations[user_id] = {
              current_date: current_date,
              days: user_rows.map { |row| [ Date.parse(row["day_group"].to_s), row["duration"].to_f.round ] }
                .sort_by { |date, _| date }.reverse
            }
          end
        end

        result = user_ids.index_with { |id| streak_cache["#{cache_prefix}_#{id}"] || 0 }
        daily_durations.each do |user_id, data|
          current_date = data[:current_date]
          eligible_days = data[:days].filter_map { |date, duration| date if date <= current_date && duration >= 15 * 60 }

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
          Rails.cache.write("#{cache_prefix}_#{user_id}", streak, expires_in: 1.hour)
        end

        result
      end

      private

      def deduped(scope) = scope.final

      def capped_diff_sql(timeout, partition_expr = nil)
        partition = partition_expr ? "PARTITION BY #{partition_expr} " : ""
        "least(" \
          "time - lagInFrame(time, 1, time) OVER (" \
          "#{partition}ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), " \
          "#{timeout})"
      end

      def day_group_sql(timezone)
        "toDate(toTimeZone(toDateTime64(time, 3), #{connection.quote(resolve_timezone(timezone))}))"
      end

      def resolve_timezone(timezone)
        return timezone if TZInfo::Timezone.all_identifiers.include?(timezone)

        Rails.logger.warn "Invalid timezone for ClickHouse duration query: #{timezone.inspect}. Defaulting to UTC."
        "UTC"
      end

      def to_epoch(value)
        value.respond_to?(:to_f) ? value.to_f : value
      end

      def cast_fields_hash_value(key, value)
        return nil if value.nil?

        case key
        when *INTEGER_HASH_KEYS then value.to_s.strip.empty? ? nil : value.to_i
        when *STRING_HASH_KEYS then value.to_s
        when "time" then value.to_f
        when "is_write" then cast_boolean(value)
        when "dependencies" then Array(value).map(&:to_s)
        else value
        end
      end

      def cast_boolean(value)
        return value if value == true || value == false

        %w[true t 1 yes on].include?(value.to_s.downcase)
      end
    end
  end
end
