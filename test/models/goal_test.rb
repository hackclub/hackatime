require "test_helper"

class GoalTest < ActiveSupport::TestCase
  test "normalizes language and project arrays" do
    user = User.create!
    goal = user.goals.create!(
      period: "day",
      target_seconds: 1800,
      languages: [ "Ruby", "Ruby", "", nil ],
      projects: [ "alpha", "", "alpha" ]
    )

    assert_equal [ "Ruby" ], goal.languages
    assert_equal [ "alpha" ], goal.projects
  end

  test "requires supported period" do
    user = User.create!
    goal = user.goals.build(period: "year", target_seconds: 1800)

    assert_not goal.valid?
    assert goal.errors[:period].any?
  end

  test "requires positive target seconds" do
    user = User.create!
    goal = user.goals.build(period: "day", target_seconds: 0)

    assert_not goal.valid?
    assert goal.errors[:target_seconds].any?
  end

  test "rejects targets longer than possible day" do
    user = User.create!
    goal = user.goals.build(period: "day", target_seconds: 25.hours.to_i)

    assert_not goal.valid?
    assert_includes goal.errors[:target_seconds], "cannot exceed 24 hours for a day goal"
  end

  test "rejects targets longer than possible week" do
    user = User.create!
    goal = user.goals.build(period: "week", target_seconds: (7.days + 1.hour).to_i)

    assert_not goal.valid?
    assert_includes goal.errors[:target_seconds], "cannot exceed 168 hours for a week goal"
  end

  test "rejects targets longer than possible month" do
    user = User.create!
    goal = user.goals.build(period: "month", target_seconds: (31.days + 1.hour).to_i)

    assert_not goal.valid?
    assert_includes goal.errors[:target_seconds], "cannot exceed 744 hours for a month goal"
  end

  test "rejects exact duplicate goals for user" do
    user = User.create!

    user.goals.create!(
      period: "week",
      target_seconds: 3600,
      languages: [ "Ruby" ],
      projects: [ "alpha" ]
    )

    duplicate = user.goals.build(
      period: "week",
      target_seconds: 3600,
      languages: [ "Ruby" ],
      projects: [ "alpha" ]
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:base], "duplicate goal"
  end

  test "rejects duplicate goals when languages and projects are in different order" do
    user = User.create!

    user.goals.create!(
      period: "week",
      target_seconds: 3600,
      languages: [ "Ruby", "Python" ],
      projects: [ "beta", "alpha" ]
    )

    duplicate = user.goals.build(
      period: "week",
      target_seconds: 3600,
      languages: [ "Python", "Ruby" ],
      projects: [ "alpha", "beta" ]
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:base], "duplicate goal"
    assert_equal [ "Python", "Ruby" ], duplicate.languages
    assert_equal [ "alpha", "beta" ], duplicate.projects
  end

  test "limits users to five goals" do
    user = User.create!

    5.times do |index|
      user.goals.create!(
        period: "day",
        target_seconds: 1800 + index,
        languages: [],
        projects: []
      )
    end

    extra_goal = user.goals.build(period: "month", target_seconds: 9999)

    assert_not extra_goal.valid?
    assert_includes extra_goal.errors[:base], "cannot have more than 5 goals"
  end

  test "notifications default to disabled" do
    user = User.create!
    goal = user.goals.create!(period: "day", target_seconds: 1800)

    assert_equal false, goal.notify_slack
    assert_equal false, goal.notify_email
    assert_not goal.notifications_enabled?
  end

  test "notifications_enabled scope returns goals with any channel enabled" do
    user = User.create!
    plain = user.goals.create!(period: "day", target_seconds: 1800)
    slack = user.goals.create!(period: "day", target_seconds: 3600, notify_slack: true)
    email = user.goals.create!(period: "day", target_seconds: 7200, notify_email: true)

    assert_equal [ slack.id, email.id ].sort, Goal.notifications_enabled.order(:id).pluck(:id).sort
  end

  test "time_window follows period in the given time zone" do
    user = User.create!
    day_goal = user.goals.build(period: "day", target_seconds: 1800)
    week_goal = user.goals.build(period: "week", target_seconds: 1800)
    month_goal = user.goals.build(period: "month", target_seconds: 1800)

    Time.use_zone(ActiveSupport::TimeZone["America/New_York"]) do
      now = Time.zone.parse("2026-08-19 12:00")

      assert_equal now.beginning_of_day..now.end_of_day, day_goal.time_window(now: now)
      assert_equal now.beginning_of_week(:monday)..now.end_of_week(:monday), week_goal.time_window(now: now)
      assert_equal now.beginning_of_month..now.end_of_month, month_goal.time_window(now: now)
    end
  end

  test "payload exposes notification settings" do
    user = User.create!
    goal = user.goals.create!(period: "day", target_seconds: 1800, notify_slack: true, notify_email: true)

    payload = goal.as_programming_goal_payload

    assert_equal true, payload[:notify_slack]
    assert_equal true, payload[:notify_email]
  end

  test "scope_description reflects languages and projects" do
    user = User.create!

    unscoped = user.goals.build(period: "day", target_seconds: 1800)
    language_only = user.goals.build(period: "day", target_seconds: 1800, languages: [ "Rust" ])
    project_only = user.goals.build(period: "day", target_seconds: 1800, projects: [ "hackatime" ])
    both = user.goals.build(period: "day", target_seconds: 1800, languages: [ "Rust", "Go" ], projects: [ "hackatime" ])

    assert_equal "coding goal", unscoped.scope_description
    assert_equal "Rust coding goal", language_only.scope_description
    assert_equal "coding goal for hackatime", project_only.scope_description
    assert_equal "Rust, Go coding goal for hackatime", both.scope_description
  end

  test "about_to_miss is false while the goal is met" do
    user = User.create!
    goal = user.goals.build(period: "day", target_seconds: 1800)

    Time.use_zone(ActiveSupport::TimeZone["UTC"]) do
      now = Time.zone.parse("2026-08-19 23:00")

      assert_not goal.about_to_miss?(now: now, tracked_seconds: goal.target_seconds)
      assert_not goal.about_to_miss?(now: now, tracked_seconds: goal.target_seconds + 1)
    end
  end

  test "about_to_miss triggers past the elapsed threshold when behind" do
    user = User.create!
    goal = user.goals.build(period: "day", target_seconds: 3600)

    Time.use_zone(ActiveSupport::TimeZone["UTC"]) do
      before_threshold = Time.zone.parse("2026-08-19 12:00") # 50% of the day
      after_threshold = Time.zone.parse("2026-08-19 20:00") # ~83% of the day

      assert_not goal.about_to_miss?(now: before_threshold, tracked_seconds: 60)
      assert goal.about_to_miss?(now: after_threshold, tracked_seconds: 60)
    end
  end
end
