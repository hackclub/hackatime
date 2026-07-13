module HeartbeatIntervals
  class Calculator
    DIMENSIONS = %i[project language editor operating_system machine category entity branch].freeze
    VALID_TIME_RANGE = 0..253402300799

    def self.call(rows, reason:)
      new(rows, reason:).call
    end

    def initialize(rows, reason:)
      @rows = rows.map { |row| row.transform_keys(&:to_s) }
      @reason = reason
      @previous_times = {}
      @seen_days = Set.new
    end

    def call
      live_rows.map { |row| delta_for(row) }
    end

    private

    attr_reader :rows, :reason, :previous_times, :seen_days

    def live_rows
      rows.reject { |row| row["deleted_at"].present? || row["time"].nil? }
        .select { |row| VALID_TIME_RANGE.cover?(row["time"].to_f) }
        .sort_by { |row| [ row["user_id"].to_i, row["time"].to_f, row["id"].to_i ] }
    end

    def delta_for(row)
      now = Time.current
      delta = {
        delta_id: Clickhouse::HeartbeatWriter.generate_id(now),
        user_id: row["user_id"].to_i,
        day: Time.at(row["time"].to_f).utc.to_date,
        time: row["time"].to_f,
        heartbeat_count_delta: 1,
        reason: reason,
        created_at: now
      }

      DIMENSIONS.each do |dimension|
        value = row[dimension.to_s]
        delta[dimension] = if dimension == :project
          value.to_s
        else
          value.nil? ? HeartbeatIntervals::NULL_DIMENSION_VALUE : value.to_s
        end
      end
      user_seconds, user_first_seconds = interval(row, :user)
      delta[:user_seconds_delta] = user_seconds
      delta[:user_first_seconds_delta] = user_first_seconds
      DIMENSIONS.each do |dimension|
        seconds, first_seconds = interval(row, dimension)
        delta["#{dimension}_seconds_delta"] = seconds
        delta["#{dimension}_first_seconds_delta"] = first_seconds
      end
      delta
    end

    def interval(row, dimension)
      value = dimension == :user ? nil : row[dimension.to_s]
      return [ 0, 0 ] if dimension == :project && value.blank?

      key = [ row["user_id"].to_i, dimension, value ]
      previous_time = previous_times[key]
      current_time = row["time"].to_f
      previous_times[key] = current_time
      day_key = [ *key, Time.at(current_time).utc.to_date ]
      first_in_day = seen_days.add?(day_key)
      return [ 0, 0 ] unless previous_time

      diff = current_time - previous_time
      return [ 0, 0 ] if diff <= 0

      seconds = [ diff, Clickhouse::Heartbeat.heartbeat_timeout_duration.to_i ].min
      [ seconds, first_in_day ? seconds : 0 ]
    end
  end
end
