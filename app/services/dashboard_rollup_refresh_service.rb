class DashboardRollupRefreshService < ApplicationService
  GROUPED_DIMENSIONS = %i[project language editor operating_system category].freeze

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
end
