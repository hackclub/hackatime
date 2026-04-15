require "test_helper"

class DashboardRollupRefreshServiceTest < ActiveSupport::TestCase
  test "rebuilds dashboard rollups from current heartbeat aggregates" do
    user = User.create!(timezone: "UTC")

    create_heartbeat(user, "2026-04-07 09:00:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-07 09:01:00 UTC", project: "alpha", language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-13 10:00:00 UTC", project: nil, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-13 10:01:00 UTC", project: nil, language: "ruby", editor: "vscode", operating_system: "macos", category: "coding")
    create_heartbeat(user, "2026-04-13 10:03:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "coding")
    create_heartbeat(user, "2026-04-13 10:05:00 UTC", project: "beta", language: "javascript", editor: "zed", operating_system: "linux", category: "browsing")

    DashboardRollupRefreshService.new(user: user).call

    total_row = DashboardRollup.find_by!(user: user, dimension: DashboardRollup::TOTAL_DIMENSION)

    assert_equal user.heartbeats.duration_seconds, total_row.total_seconds
    assert_equal user.heartbeats.count, total_row.source_heartbeats_count
    assert_equal user.heartbeats.maximum(:time), total_row.source_max_heartbeat_time

    assert_equal(
      user.heartbeats.group(:project).duration_seconds,
      DashboardRollup.where(user: user, dimension: "project").to_h { |row| [ row.bucket, row.total_seconds ] }
    )
    assert_equal(
      user.heartbeats.group(:language).duration_seconds,
      DashboardRollup.where(user: user, dimension: "language").to_h { |row| [ row.bucket, row.total_seconds ] }
    )

    assert_equal(
      user.heartbeats.daily_durations(user_timezone: user.timezone).to_h.transform_keys(&:iso8601),
      DashboardRollup.where(user: user, dimension: DashboardRollupRefreshService::DAILY_DURATION_DIMENSION).to_h { |row| [ row.bucket, row.total_seconds ] }
    )

    today_scope = Time.use_zone(user.timezone) do
      now = Time.zone.now
      user.heartbeats.where(time: now.beginning_of_day.to_i..now.end_of_day.to_i)
    end

    context_row = DashboardRollup.find_by(user: user, dimension: DashboardRollupRefreshService::TODAY_CONTEXT_DIMENSION)
    assert_equal [ user.timezone, Time.use_zone(user.timezone) { Time.zone.today.iso8601 } ], JSON.parse(context_row.bucket_value)

    today_total = DashboardRollup.find_by(user: user, dimension: DashboardRollupRefreshService::TODAY_TOTAL_DURATION_DIMENSION)
    assert_equal today_scope.duration_seconds, today_total.total_seconds

    expected_language_counts = today_scope
      .where.not(language: [ nil, "" ])
      .group(:language)
      .count
      .each_with_object({}) do |(language, count), grouped|
        categorized = language&.categorize_language
        next if categorized.blank?

        grouped[categorized] = (grouped[categorized] || 0) + count.to_i
      end
    assert_equal(
      expected_language_counts,
      DashboardRollup.where(user: user, dimension: DashboardRollupRefreshService::TODAY_LANGUAGE_COUNT_DIMENSION).to_h { |row| [ row.bucket, row.total_seconds ] }
    )

    expected_editor_counts = today_scope
      .where.not(editor: [ nil, "" ])
      .group(:editor)
      .count
      .transform_values(&:to_i)
    assert_equal(
      expected_editor_counts,
      DashboardRollup.where(user: user, dimension: DashboardRollupRefreshService::TODAY_EDITOR_COUNT_DIMENSION).to_h { |row| [ row.bucket, row.total_seconds ] }
    )

    %w[day week month].each do |period|
      period_scope = period_scope(user, period)

      total_row = DashboardRollup.find_by(user: user, dimension: DashboardRollupRefreshService::GOALS_PERIOD_TOTAL_DIMENSION, bucket_value: period)
      assert_equal period_scope.duration_seconds, total_row.total_seconds
    end
  end

  private

  def create_heartbeat(user, timestamp, project:, language:, editor:, operating_system:, category:)
    Heartbeat.create!(
      user: user,
      time: Time.parse(timestamp).to_f,
      project: project,
      language: language,
      editor: editor,
      operating_system: operating_system,
      category: category,
      source_type: :test_entry
    )
  end

  def period_scope(user, period)
    range = Time.use_zone(user.timezone) do
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

    user.heartbeats.where(time: range.begin.to_i..range.end.to_i)
  end
end
