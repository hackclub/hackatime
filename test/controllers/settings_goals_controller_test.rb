require "test_helper"

class SettingsGoalsControllerTest < ActionDispatch::IntegrationTest
  test "show renders goals settings page" do
    user = User.create!
    sign_in_as(user)

    get my_settings_goals_path

    assert_response :success
    assert_inertia_component "Users/Settings/Goals"

    page = inertia_page
    assert_equal my_settings_goals_path, page.dig("props", "section_paths", "goals")
    assert_equal [], page.dig("props", "user", "programming_goals")
  end

  test "create saves valid goal" do
    user = User.create!
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

  test "update rejects more than five goals" do
    user = User.create!
    sign_in_as(user)

    goals = 6.times.map do |index|
      {
        id: "goal-#{index}",
        period: "day",
        target_seconds: 1800 + index,
        languages: [],
        projects: []
      }
    end

    patch my_settings_goals_path, params: {
      user: {
        programming_goals_json: goals.to_json
      }
    }

    assert_response :unprocessable_entity
    assert_equal 0, user.reload.goals.count
  end

  test "update rejects invalid goal period" do
    user = User.create!
    sign_in_as(user)

    goals = [
      {
        id: "invalid-period",
        period: "year",
        target_seconds: 1800,
        languages: [],
        projects: []
      }
    ]

    patch my_settings_goals_path, params: {
      user: {
        programming_goals_json: goals.to_json
      }
    }

    assert_response :unprocessable_entity
    assert_equal 0, user.reload.goals.count
  end

  test "update rejects nonpositive goal target" do
    user = User.create!
    sign_in_as(user)

    goals = [
      {
        id: "invalid-target",
        period: "day",
        target_seconds: 0,
        languages: [],
        projects: []
      }
    ]

    patch my_settings_goals_path, params: {
      user: {
        programming_goals_json: goals.to_json
      }
    }

    assert_response :unprocessable_entity
    assert_equal 0, user.reload.goals.count
  end

  test "update rejects impossible day target" do
    user = User.create!
    sign_in_as(user)

    goals = [
      {
        id: "impossible-day-target",
        period: "day",
        target_seconds: 25.hours.to_i,
        languages: [],
        projects: []
      }
    ]

    patch my_settings_goals_path, params: {
      user: {
        programming_goals_json: goals.to_json
      }
    }

    assert_response :unprocessable_entity
    assert_equal 0, user.reload.goals.count
  end

  private

  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]
  end
end
