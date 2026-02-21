require "test_helper"

class SettingsGoalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "show renders goals settings page" do
    user = users(:one)
    sign_in_as(user)

    get my_settings_goals_path

    assert_response :success
    assert_inertia_component "Users/Settings/Goals"

    page = inertia_page
    assert_equal my_settings_goals_path, page.dig("props", "section_paths", "goals")
    assert_equal [], page.dig("props", "user", "programming_goals")
  end

  test "create saves valid goal" do
    user = users(:one)
    sign_in_as(user)

    post my_settings_goals_create_path, params: {
      goal: {
        period: "day",
        target_seconds: 3600,
        languages: [ "Ruby" ],
        projects: [ "hackatime" ]
      }
    }

    assert_response :redirect
    assert_redirected_to my_settings_goals_path

    saved_goal = user.reload.goals.first
    assert_equal "day", saved_goal.period
    assert_equal [ "Ruby" ], saved_goal.languages
    assert_equal [ "hackatime" ], saved_goal.projects
  end

  test "rejects sixth goal when limit reached" do
    user = users(:one)
    sign_in_as(user)

    5.times do |index|
      user.goals.create!(
        period: "day",
        target_seconds: 1800 + index,
        languages: [],
        projects: []
      )
    end

    post my_settings_goals_create_path, params: {
      goal: {
        period: "day",
        target_seconds: 9999,
        languages: [],
        projects: []
      }
    }

    assert_response :unprocessable_entity
    assert_equal 5, user.reload.goals.count
  end

  test "create rejects invalid goal period" do
    user = users(:one)
    sign_in_as(user)

    post my_settings_goals_create_path, params: {
      goal: {
        period: "year",
        target_seconds: 1800,
        languages: [],
        projects: []
      }
    }

    assert_response :unprocessable_entity
    assert_equal 0, user.reload.goals.count
  end

  test "create rejects nonpositive goal target" do
    user = users(:one)
    sign_in_as(user)

    post my_settings_goals_create_path, params: {
      goal: {
        period: "day",
        target_seconds: 0,
        languages: [],
        projects: []
      }
    }

    assert_response :unprocessable_entity
    assert_equal 0, user.reload.goals.count
  end

  test "create rejects impossible day target" do
    user = users(:one)
    sign_in_as(user)

    post my_settings_goals_create_path, params: {
      goal: {
        period: "day",
        target_seconds: 25.hours.to_i,
        languages: [],
        projects: []
      }
    }

    assert_response :unprocessable_entity
    assert_equal 0, user.reload.goals.count
  end

  test "update saves valid goal changes" do
    user = users(:one)
    goal = user.goals.create!(
      period: "day",
      target_seconds: 1800,
      languages: [ "Ruby" ],
      projects: [ "alpha" ]
    )
    sign_in_as(user)

    patch my_settings_goal_update_path(goal_id: goal.id), params: {
      goal: {
        period: "week",
        target_seconds: 7200,
        languages: [ "Python" ],
        projects: [ "beta" ]
      }
    }

    assert_response :redirect
    assert_redirected_to my_settings_goals_path

    goal.reload
    assert_equal "week", goal.period
    assert_equal 7200, goal.target_seconds
    assert_equal [ "Python" ], goal.languages
    assert_equal [ "beta" ], goal.projects
  end

  test "update rejects invalid goal and re-renders settings page" do
    user = users(:one)
    goal = user.goals.create!(period: "day", target_seconds: 1800)
    sign_in_as(user)

    patch my_settings_goal_update_path(goal_id: goal.id), params: {
      goal: {
        period: "year",
        target_seconds: 1800
      }
    }

    assert_response :unprocessable_entity
    assert_inertia_component "Users/Settings/Goals"
    assert_equal "day", goal.reload.period
  end

  test "destroy removes goal" do
    user = users(:one)
    goal = user.goals.create!(period: "day", target_seconds: 1800)
    sign_in_as(user)

    assert_difference -> { user.reload.goals.count }, -1 do
      delete my_settings_goal_destroy_path(goal_id: goal.id)
    end

    assert_response :redirect
    assert_redirected_to my_settings_goals_path
  end
end
