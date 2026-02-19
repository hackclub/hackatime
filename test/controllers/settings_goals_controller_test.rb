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

  test "create saves valid goals" do
    user = User.create!
    sign_in_as(user)

    post my_settings_goals_create_path, params: {
      goal: {
        period: "day",
        target_seconds: 3600,
        languages: [ "Ruby", "Ruby", "" ],
        projects: [ "hackatime", "" ]
      }
    }

    assert_response :redirect
    assert_redirected_to my_settings_goals_path

    post my_settings_goals_create_path, params: {
      goal: {
        period: "week",
        target_seconds: 7200,
        languages: [],
        projects: []
      }
    }

    assert_response :redirect

    saved_goals = user.reload.goals.order(:created_at)
    assert_equal 2, saved_goals.size
    assert_equal [ "Ruby" ], saved_goals.first.languages
    assert_equal [ "hackatime" ], saved_goals.first.projects
  end

  test "create rejects more than five goals" do
    user = User.create!
    sign_in_as(user)

    5.times do |index|
      post my_settings_goals_create_path, params: {
        goal: {
          period: "day",
          target_seconds: 1800 + index,
          languages: [],
          projects: []
        }
      }
      assert_response :redirect
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
    user = User.create!
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
    user = User.create!
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
    user = User.create!
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

  private

  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]
  end
end
