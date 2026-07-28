class DashboardRollupRefreshService < ApplicationService
  GROUPED_DIMENSIONS = DashboardData::Snapshots::GROUPED_DIMENSIONS
  WEEKLY_PROJECT_DIMENSION = DashboardData::Snapshots::WEEKLY_PROJECT_DIMENSION

  def initialize(user:)
    @user = user
    @scope = user.heartbeats_excluding_archived_projects
  end

  def call
    now = Time.current
    records = [
      build_record(dimension: DashboardRollup::TOTAL_DIMENSION, bucket: nil,
                   total_seconds: @scope.duration_seconds, now:,
                   source_heartbeats_count: @scope.count,
                   source_max_heartbeat_time: @scope.maximum(:time)),
      build_record(dimension: DashboardRollup::FILTER_OPTIONS_DIMENSION, bucket: nil,
                   total_seconds: 0, now:, payload: filter_options_payload),
      build_record(dimension: DashboardRollup::ACTIVITY_GRAPH_DIMENSION, bucket: nil,
                   total_seconds: 0, now:,
                   payload: DashboardData::Snapshots.activity_graph_snapshot(user: @user, scope: @scope)),
      build_record(dimension: DashboardRollup::TODAY_STATS_DIMENSION, bucket: nil,
                   total_seconds: 0, now:,
                   payload: DashboardData::Snapshots.today_stats_snapshot(user: @user, scope: @scope))
    ]

    GROUPED_DIMENSIONS.each do |dimension|
      grouped_durations(dimension).each do |bucket, total_seconds|
        records << build_record(dimension:, bucket:, total_seconds:, now:)
      end
    end
    DashboardData::Snapshots.weekly_project_stats(user: @user, scope: @scope).each do |week_key, projects|
      projects.each do |project, total_seconds|
        records << build_record(dimension: WEEKLY_PROJECT_DIMENSION,
                                bucket: [ week_key, project ].to_json, total_seconds:, now:)
      end
    end
    DashboardData::Snapshots.project_details_snapshot(scope: @scope).each do |project, details|
      records << build_record(
        dimension: DashboardRollup::PROJECT_DETAILS_DIMENSION, bucket: project,
        total_seconds: details.fetch(:total_seconds), now:,
        source_heartbeats_count: details.fetch(:total_heartbeats),
        source_max_heartbeat_time: details.fetch(:last_heartbeat),
        payload: {
          first_heartbeat: details.fetch(:first_heartbeat),
          last_heartbeat: details.fetch(:last_heartbeat),
          languages: details.fetch(:languages)
        }
      )
    end

    DashboardRollup.transaction do
      DashboardRollup.where(user_id: @user.id).delete_all
      DashboardRollup.insert_all!(records)
    end
    DashboardRollup.clear_dirty(@user.id)
  end

  private

  def build_record(
    dimension:,
    bucket:,
    total_seconds:,
    now:,
    source_heartbeats_count: nil,
    source_max_heartbeat_time: nil,
    payload: nil
  )
    {
      user_id: @user.id,
      dimension: dimension.to_s,
      bucket_value: bucket.to_s,
      bucket_value_present: !bucket.nil?,
      total_seconds: total_seconds.to_i,
      source_heartbeats_count:,
      source_max_heartbeat_time:,
      payload:,
      created_at: now,
      updated_at: now
    }
  end

  def grouped_durations(dimension)
    return DashboardData::Snapshots.project_grouped_durations(@scope) if dimension == :project
    Heartbeat.attributed_durations_by(@scope, dimension)
  end

  def filter_options_payload
    GROUPED_DIMENSIONS.index_with { |d| @scope.distinct.pluck(d).compact_blank.sort }
  end
end
