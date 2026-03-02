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
end
