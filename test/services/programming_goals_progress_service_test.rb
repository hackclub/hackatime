require "test_helper"

class ProgrammingGoalsProgressServiceTest < ActiveSupport::TestCase
  setup do
    @original_timeout = Heartbeat.heartbeat_timeout_duration
    Heartbeat.heartbeat_timeout_duration(1.second)
  end

  teardown do
    Heartbeat.heartbeat_timeout_duration(@original_timeout)
  end

  test "day goal uses current day in user timezone" do
    user = User.create!(timezone: "America/New_York")
    user.goals.create!(period: "day", target_seconds: 10)

    travel_to Time.utc(2026, 1, 14, 16, 0, 0) do
      create_heartbeat_pair(user, "2026-01-14 09:00:00")
      create_heartbeat_pair(user, "2026-01-13 09:00:00")

      progress = ProgrammingGoalsProgressService.new(user: user).call

      assert_equal 1, progress.first[:tracked_seconds]
    end
  end

  test "week goal starts on monday" do
    user = User.create!(timezone: "America/New_York")
    user.goals.create!(period: "week", target_seconds: 10)

    travel_to Time.utc(2026, 1, 14, 16, 0, 0) do
      timezone = ActiveSupport::TimeZone[user.timezone]
      monday = timezone.now.beginning_of_week(:monday)

      create_heartbeat_pair(user, monday.change(hour: 9, min: 0, sec: 0))
      create_heartbeat_pair(user, (monday - 1.day).change(hour: 9, min: 0, sec: 0))

      progress = ProgrammingGoalsProgressService.new(user: user).call

      assert_equal 1, progress.first[:tracked_seconds]
    end
  end

  test "month goal uses current calendar month" do
    user = User.create!(timezone: "America/New_York")
    user.goals.create!(period: "month", target_seconds: 10)

    travel_to Time.utc(2026, 2, 15, 17, 0, 0) do
      create_heartbeat_pair(user, "2026-02-01 08:00:00")
      create_heartbeat_pair(user, "2026-01-31 08:00:00")

      progress = ProgrammingGoalsProgressService.new(user: user).call

      assert_equal 1, progress.first[:tracked_seconds]
    end
  end

  test "language and project filters apply with and behavior" do
    user = User.create!(timezone: "America/New_York")

    language_goal = user.goals.create!(
      period: "day",
      target_seconds: 10,
      languages: [ "Ruby" ],
      projects: []
    )
    project_goal = user.goals.create!(
      period: "day",
      target_seconds: 10,
      languages: [],
      projects: [ "alpha" ]
    )
    and_goal = user.goals.create!(
      period: "day",
      target_seconds: 10,
      languages: [ "Ruby" ],
      projects: [ "alpha" ]
    )

    travel_to Time.utc(2026, 1, 14, 16, 0, 0) do
      create_heartbeat_pair(user, "2026-01-14 09:00:00", language: "rb", project: "alpha")
      create_heartbeat_pair(user, "2026-01-14 09:10:00", language: "python", project: "alpha")
      create_heartbeat_pair(user, "2026-01-14 09:20:00", language: "rb", project: "beta")

      progress = ProgrammingGoalsProgressService.new(user: user).call.index_by { |goal| goal[:id] }

      assert_equal 3, progress[language_goal.id.to_s][:tracked_seconds]
      assert_equal 3, progress[project_goal.id.to_s][:tracked_seconds]
      assert_equal 1, progress[and_goal.id.to_s][:tracked_seconds]
    end
  end

  test "completion percent is capped at one hundred" do
    user = User.create!(timezone: "America/New_York")
    user.goals.create!(period: "day", target_seconds: 1)

    travel_to Time.utc(2026, 1, 14, 16, 0, 0) do
      create_heartbeat_pair(user, "2026-01-14 09:00:00")
      create_heartbeat_pair(user, "2026-01-14 09:05:00")

      progress = ProgrammingGoalsProgressService.new(user: user).call.first

      assert_equal 100, progress[:completion_percent]
      assert_equal true, progress[:complete]
    end
  end

  test "uses rollup aggregates for unfiltered project-only and language-only goals" do
    user = User.create!(timezone: "America/New_York")

    unfiltered_goal = user.goals.create!(period: "day", target_seconds: 10)
    project_goal = user.goals.create!(period: "day", target_seconds: 10, projects: [ "alpha" ])
    language_goal = user.goals.create!(period: "day", target_seconds: 10, languages: [ "Ruby" ])

    travel_to Time.utc(2026, 1, 14, 16, 0, 0) do
      create_heartbeat_pair(user, "2026-01-14 09:00:00", language: "rb", project: "alpha")
      create_heartbeat_pair(user, "2026-01-14 09:10:00", language: "python", project: "alpha")
      create_heartbeat_pair(user, "2026-01-14 09:20:00", language: "rb", project: "beta")

      DashboardRollupRefreshService.new(user: user).call
      rows = DashboardRollup.where(user: user).to_a

      progress = ProgrammingGoalsProgressService.new(user: user, rollup_rows: rows).call.index_by { |goal| goal[:id] }

      assert_equal 5, progress[unfiltered_goal.id.to_s][:tracked_seconds]
      assert_equal 3, progress[project_goal.id.to_s][:tracked_seconds]
      assert_equal 3, progress[language_goal.id.to_s][:tracked_seconds]
    end
  end

  test "falls back to heartbeat queries for combined language and project filters" do
    user = User.create!(timezone: "America/New_York")
    and_goal = user.goals.create!(
      period: "day",
      target_seconds: 10,
      languages: [ "Ruby" ],
      projects: [ "alpha" ]
    )

    travel_to Time.utc(2026, 1, 14, 16, 0, 0) do
      create_heartbeat_pair(user, "2026-01-14 09:00:00", language: "rb", project: "alpha")
      create_heartbeat_pair(user, "2026-01-14 09:10:00", language: "python", project: "alpha")
      create_heartbeat_pair(user, "2026-01-14 09:20:00", language: "rb", project: "beta")

      DashboardRollupRefreshService.new(user: user).call
      rows = DashboardRollup.where(user: user).to_a

      progress = ProgrammingGoalsProgressService.new(user: user, rollup_rows: rows).call.index_by { |goal| goal[:id] }

      assert_equal 1, progress[and_goal.id.to_s][:tracked_seconds]
    end
  end

  test "falls back to heartbeat queries when goals rollup dimensions are missing" do
    user = User.create!(timezone: "America/New_York")
    goal = user.goals.create!(period: "day", target_seconds: 10)

    travel_to Time.utc(2026, 1, 14, 16, 0, 0) do
      create_heartbeat_pair(user, "2026-01-14 09:00:00", language: "rb", project: "alpha")
      create_heartbeat_pair(user, "2026-01-14 09:10:00", language: "python", project: "alpha")

      DashboardRollupRefreshService.new(user: user).call
      stale_rows = DashboardRollup.where(user: user)
        .where.not(
          dimension: [
            DashboardRollupRefreshService::GOALS_PERIOD_TOTAL_DIMENSION,
            DashboardRollupRefreshService::GOALS_PERIOD_PROJECT_DIMENSION,
            DashboardRollupRefreshService::GOALS_PERIOD_LANGUAGE_DIMENSION
          ]
        )
        .to_a

      progress = ProgrammingGoalsProgressService.new(user: user, rollup_rows: stale_rows).call

      assert_equal 2, progress.first[:tracked_seconds]
      assert_equal goal.id.to_s, progress.first[:id]
    end
  end

  private

  def create_heartbeat_pair(user, start_time, language: "Ruby", project: "alpha")
    start_at = to_time_in_zone(user.timezone, start_time)

    Heartbeat.create!(
      user: user,
      time: start_at.to_i,
      language: language,
      project: project,
      category: "coding",
      source_type: :test_entry
    )

    Heartbeat.create!(
      user: user,
      time: (start_at + 1.second).to_i,
      language: language,
      project: project,
      category: "coding",
      source_type: :test_entry
    )
  end

  def to_time_in_zone(timezone_name, value)
    timezone = ActiveSupport::TimeZone[timezone_name]

    if value.is_a?(String)
      timezone.parse(value)
    else
      value.in_time_zone(timezone)
    end
  end
end
