class DashboardRollupRefreshService < ApplicationService
  GROUPED_DIMENSIONS = DashboardData::Snapshots::GROUPED_DIMENSIONS
  WEEKLY_PROJECT_DIMENSION = DashboardData::Snapshots::WEEKLY_PROJECT_DIMENSION

  def initialize(user:)
    @user = user
    @scope = user.heartbeats
  end

  def call
    now = Time.current
    records = [
      build_total_record(now),
      build_filter_options_record(now),
      build_activity_graph_record(now),
      build_today_stats_record(now)
    ]

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

  def build_activity_graph_record(now)
    build_record(
      dimension: DashboardRollup::ACTIVITY_GRAPH_DIMENSION,
      bucket: nil,
      total_seconds: 0,
      now: now,
      payload: activity_graph_payload
    )
  end

  def build_filter_options_record(now)
    build_record(
      dimension: DashboardRollup::FILTER_OPTIONS_DIMENSION,
      bucket: nil,
      total_seconds: 0,
      now: now,
      payload: filter_options_payload
    )
  end

  def build_today_stats_record(now)
    build_record(
      dimension: DashboardRollup::TODAY_STATS_DIMENSION,
      bucket: nil,
      total_seconds: 0,
      now: now,
      payload: today_stats_payload
    )
  end

  def build_record(dimension:, bucket:, total_seconds:, now:, source_heartbeats_count: nil, source_max_heartbeat_time: nil, payload: nil)
    {
      user_id: @user.id,
      dimension: dimension.to_s,
      bucket_value: bucket.to_s,
      bucket_value_present: !bucket.nil?,
      total_seconds: total_seconds.to_i,
      source_heartbeats_count: source_heartbeats_count,
      source_max_heartbeat_time: source_max_heartbeat_time,
      payload: payload,
      created_at: now,
      updated_at: now
    }
  end

  def grouped_durations(dimension)
    return DashboardData::Snapshots.project_grouped_durations(@scope) if dimension == :project

    Heartbeat.attributed_durations_by(@scope, dimension)
  end

  def weekly_project_stats
    DashboardData::Snapshots.weekly_project_stats(user: @user, scope: @scope)
  end

  def activity_graph_payload
    DashboardData::Snapshots.activity_graph_snapshot(user: @user, scope: @scope)
  end

  def filter_options_payload
    GROUPED_DIMENSIONS.index_with do |dimension|
      @scope.distinct.pluck(dimension).compact_blank.sort
    end
  end

  def today_stats_payload
    DashboardData::Snapshots.today_stats_snapshot(user: @user, scope: @scope)
  end
end
