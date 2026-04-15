class DashboardRollupRefreshService < ApplicationService
  GROUPED_DIMENSIONS = %i[project language editor operating_system category].freeze
  WEEKLY_PROJECT_DIMENSION = "weekly_project".freeze
  DAILY_DURATION_DIMENSION = "daily_duration".freeze
  TODAY_CONTEXT_DIMENSION = "today_context".freeze
  TODAY_TOTAL_DURATION_DIMENSION = "today_total_duration".freeze
  TODAY_LANGUAGE_COUNT_DIMENSION = "today_language_count".freeze
  TODAY_EDITOR_COUNT_DIMENSION = "today_editor_count".freeze
  GOALS_PERIOD_TOTAL_DIMENSION = "goals_period_total".freeze
  GOALS_PERIOD_PROJECT_DIMENSION = "goals_period_project".freeze
  GOALS_PERIOD_LANGUAGE_DIMENSION = "goals_period_language".freeze
  GOALS_PERIODS = %w[day week month].freeze
  TODAY_DIMENSIONS = [
    TODAY_CONTEXT_DIMENSION,
    TODAY_TOTAL_DURATION_DIMENSION,
    TODAY_LANGUAGE_COUNT_DIMENSION,
    TODAY_EDITOR_COUNT_DIMENSION
  ].freeze
  TODAY_ROLLUP_LOCK_NAMESPACE = 42_001
  MAX_SIGNED_INT64 = (2**63) - 1
  UINT64_RANGE = 2**64

  def initialize(user:)
    @user = user
    @scope = user.heartbeats
  end

  def call
    now = Time.current
    records = [ build_total_record(now) ]
    GROUPED_DIMENSIONS.each do |dimension|
      grouped_durations(dimension).each do |bucket, total_seconds|
        records << build_record(
          dimension: dimension,
          bucket: bucket,
          total_seconds: total_seconds,
          now: now
        )
      end
    end
    weekly_project_stats.each do |week_key, projects|
      projects.each do |project, total_seconds|
        records << build_record(
          dimension: WEEKLY_PROJECT_DIMENSION,
          bucket: [ week_key, project ].to_json,
          total_seconds: total_seconds,
          now: now
        )
      end
    end

    daily_durations.each do |date_key, total_seconds|
      records << build_record(
        dimension: DAILY_DURATION_DIMENSION,
        bucket: date_key,
        total_seconds: total_seconds,
        now: now
      )
    end

    today_rollup_records(now).each do |record|
      records << record
    end

    goals_rollup_data.each do |period, period_data|
      records << build_record(
        dimension: GOALS_PERIOD_TOTAL_DIMENSION,
        bucket: period,
        total_seconds: period_data.fetch(:total),
        now: now
      )

      period_data.fetch(:project).each do |project, total_seconds|
        records << build_record(
          dimension: GOALS_PERIOD_PROJECT_DIMENSION,
          bucket: [ period, project ].to_json,
          total_seconds: total_seconds,
          now: now
        )
      end

      period_data.fetch(:language).each do |language, total_seconds|
        records << build_record(
          dimension: GOALS_PERIOD_LANGUAGE_DIMENSION,
          bucket: [ period, language ].to_json,
          total_seconds: total_seconds,
          now: now
        )
      end
    end

    DashboardRollup.transaction do
      DashboardRollup.where(user_id: @user.id).delete_all
      DashboardRollup.insert_all!(records)
    end

    DashboardRollup.clear_dirty(@user.id)
  end

  private

  def build_total_record(now)
    build_record(
      dimension: DashboardRollup::TOTAL_DIMENSION,
      bucket: nil,
      total_seconds: @scope.duration_seconds,
      now: now,
      source_heartbeats_count: @scope.count,
      source_max_heartbeat_time: @scope.maximum(:time)
    )
  end

  def build_record(dimension:, bucket:, total_seconds:, now:, source_heartbeats_count: nil, source_max_heartbeat_time: nil)
    {
      user_id: @user.id,
      dimension: dimension.to_s,
      bucket_value: bucket.to_s,
      bucket_value_present: !bucket.nil?,
      total_seconds: total_seconds.to_i,
      source_heartbeats_count: source_heartbeats_count,
      source_max_heartbeat_time: source_max_heartbeat_time,
      created_at: now,
      updated_at: now
    }
  end

  def grouped_durations(dimension)
    return project_grouped_durations if dimension == :project

    @scope.group(dimension).duration_seconds
  end

  def project_grouped_durations
    non_null = @scope.where.not(project: nil).group(:project).duration_seconds
    return non_null if @scope.where(project: nil).none?

    null_duration = @scope.where(project: nil).duration_seconds
    return non_null if null_duration.zero?

    non_null.merge(nil => null_duration)
  end

  def weekly_project_stats
    week_ranges = dashboard_week_ranges
    result = week_ranges.to_h { |week_key, *_| [ week_key, {} ] }

    relation_sql = @scope.with_valid_timestamps
      .where.not(time: nil)
      .where(time: week_ranges.last[1]..week_ranges.first[2])
      .select(:time, :project)
      .to_sql

    quoted_timezone = Heartbeat.connection.quote(@user.timezone)
    week_group_sql = "DATE_TRUNC('week', to_timestamp(time) AT TIME ZONE #{quoted_timezone})"

    rows = Heartbeat.connection.select_all(<<~SQL.squish)
      SELECT TO_CHAR(week_group, 'YYYY-MM-DD') AS week_key,
             grouped_time,
             COALESCE(SUM(diff), 0)::integer AS duration
      FROM (
        SELECT project AS grouped_time,
               #{week_group_sql} AS week_group,
               CASE
                 WHEN LAG(time) OVER (PARTITION BY project, #{week_group_sql} ORDER BY time) IS NULL THEN 0
                 ELSE LEAST(
                   time - LAG(time) OVER (PARTITION BY project, #{week_group_sql} ORDER BY time),
                   #{Heartbeat.heartbeat_timeout_duration.to_i}
                 )
               END AS diff
        FROM (#{relation_sql}) dashboard_heartbeats
      ) diffs
      GROUP BY week_group, grouped_time
      ORDER BY week_key DESC, grouped_time
    SQL

    rows.each do |row|
      result[row["week_key"]][row["grouped_time"]] = row["duration"].to_i
    end

    result
  end

  def dashboard_week_ranges
    (0..11).map do |w|
      week_start = w.weeks.ago.beginning_of_week
      [ week_start.to_date.iso8601, week_start.to_f, w.weeks.ago.end_of_week.to_f ]
    end
  end

  def daily_durations
    @scope.daily_durations(user_timezone: @user.timezone).to_h.transform_keys { |date| date.iso8601 }
  end

  def self.today_rollup_data_for(user)
    timezone = user.timezone
    Time.use_zone(timezone) do
      today_scope = user.heartbeats.today

      language_counts = today_scope
        .where.not(language: [ nil, "" ])
        .group(:language)
        .count
        .each_with_object({}) do |(language, count), grouped|
          categorized = language&.categorize_language
          next if categorized.blank?

          grouped[categorized] = (grouped[categorized] || 0) + count.to_i
        end

      editor_counts = today_scope
        .where.not(editor: [ nil, "" ])
        .group(:editor)
        .count
        .transform_values(&:to_i)

      {
        timezone: timezone,
        local_date: Time.zone.today.iso8601,
        total_duration: today_scope.duration_seconds.to_i,
        language_counts: language_counts,
        editor_counts: editor_counts
      }
    end
  end

  def self.upsert_today_rollup!(user:, data:, now: Time.current)
    records = []
    records << {
      user_id: user.id,
      dimension: TODAY_CONTEXT_DIMENSION,
      bucket_value: [ data.fetch(:timezone), data.fetch(:local_date) ].to_json,
      bucket_value_present: true,
      total_seconds: 0,
      source_heartbeats_count: nil,
      source_max_heartbeat_time: nil,
      created_at: now,
      updated_at: now
    }
    records << {
      user_id: user.id,
      dimension: TODAY_TOTAL_DURATION_DIMENSION,
      bucket_value: "",
      bucket_value_present: false,
      total_seconds: data.fetch(:total_duration).to_i,
      source_heartbeats_count: nil,
      source_max_heartbeat_time: nil,
      created_at: now,
      updated_at: now
    }

    data.fetch(:language_counts, {}).each do |language, count|
      records << {
        user_id: user.id,
        dimension: TODAY_LANGUAGE_COUNT_DIMENSION,
        bucket_value: language.to_s,
        bucket_value_present: true,
        total_seconds: count.to_i,
        source_heartbeats_count: nil,
        source_max_heartbeat_time: nil,
        created_at: now,
        updated_at: now
      }
    end

    data.fetch(:editor_counts, {}).each do |editor, count|
      records << {
        user_id: user.id,
        dimension: TODAY_EDITOR_COUNT_DIMENSION,
        bucket_value: editor.to_s,
        bucket_value_present: true,
        total_seconds: count.to_i,
        source_heartbeats_count: nil,
        source_max_heartbeat_time: nil,
        created_at: now,
        updated_at: now
      }
    end

    DashboardRollup.transaction do
      lock_key = today_rollup_lock_key(user.id)
      DashboardRollup.connection.execute(
        "SELECT pg_advisory_xact_lock(#{lock_key})"
      )
      DashboardRollup.where(user_id: user.id, dimension: TODAY_DIMENSIONS).delete_all
      DashboardRollup.insert_all!(records)
    end
  end

  def self.today_rollup_lock_key(user_id)
    namespace = TODAY_ROLLUP_LOCK_NAMESPACE.to_i & 0xffff_ffff
    id_bits = user_id.to_i & 0xffff_ffff
    raw_key = (namespace << 32) | id_bits

    raw_key > MAX_SIGNED_INT64 ? raw_key - UINT64_RANGE : raw_key
  end

  def goals_rollup_data
    GOALS_PERIODS.each_with_object({}) do |period, result|
      scope = goals_period_scope(period)
      grouped_languages = scope.group(:language).duration_seconds.each_with_object({}) do |(language, seconds), grouped|
        next if language.blank?

        categorized = language.categorize_language
        next if categorized.blank?

        grouped[categorized] = (grouped[categorized] || 0) + seconds
      end

      result[period] = {
        total: scope.duration_seconds,
        project: project_grouped_durations_for(scope),
        language: grouped_languages
      }
    end
  end

  def goals_period_scope(period)
    range = Time.use_zone(@user.timezone) do
      now = Time.zone.now
      case period
      when "day"
        now.beginning_of_day..now.end_of_day
      when "week"
        now.beginning_of_week(:monday)..now.end_of_week(:monday)
      when "month"
        now.beginning_of_month..now.end_of_month
      else
        now.beginning_of_day..now.end_of_day
      end
    end

    @scope.where(time: range.begin.to_i..range.end.to_i)
  end

  def project_grouped_durations_for(scope)
    non_null = scope.where.not(project: nil).group(:project).duration_seconds
    return non_null if scope.where(project: nil).none?

    null_duration = scope.where(project: nil).duration_seconds
    return non_null if null_duration.zero?

    non_null.merge(nil => null_duration)
  end

  def today_rollup_records(now)
    data = self.class.today_rollup_data_for(@user)
    records = []

    records << build_record(
      dimension: TODAY_CONTEXT_DIMENSION,
      bucket: [ data.fetch(:timezone), data.fetch(:local_date) ].to_json,
      total_seconds: 0,
      now: now
    )
    records << build_record(
      dimension: TODAY_TOTAL_DURATION_DIMENSION,
      bucket: nil,
      total_seconds: data.fetch(:total_duration),
      now: now
    )

    data.fetch(:language_counts).each do |language, count|
      records << build_record(
        dimension: TODAY_LANGUAGE_COUNT_DIMENSION,
        bucket: language,
        total_seconds: count,
        now: now
      )
    end

    data.fetch(:editor_counts).each do |editor, count|
      records << build_record(
        dimension: TODAY_EDITOR_COUNT_DIMENSION,
        bucket: editor,
        total_seconds: count,
        now: now
      )
    end

    records
  end
end
