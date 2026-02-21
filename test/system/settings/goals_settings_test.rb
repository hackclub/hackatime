require "application_system_test_case"
require_relative "test_helpers"

class GoalsSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "goals settings page renders" do
    assert_settings_page(
      path: my_settings_goals_path,
      marker_text: "Programming Goals"
    )
    assert_text(/Active Goal/i)
  end

  test "goals settings can create edit and delete goal" do
    visit my_settings_goals_path

    assert_text(/0 Active Goals/i)
    click_on "New goal"

    within_modal do
      click_on "2h"
      click_on "Create Goal"
    end

    assert_text "Goal created."
    assert_text(/1 Active Goal/i)
    assert_text "Daily: 2h"
    assert_equal 2.hours.to_i, @user.reload.goals.first.target_seconds

    click_on "Edit"
    within_modal do
      click_on "30m"
      click_on "Update Goal"
    end

    assert_text "Goal updated."
    assert_text "Daily: 30m"
    assert_equal 30.minutes.to_i, @user.reload.goals.first.target_seconds

    click_on "Delete"
    assert_text "Goal deleted."
    assert_text(/0 Active Goals/i)
    assert_equal 0, @user.reload.goals.count
  end

  test "goals settings rejects duplicate goal" do
    @user.goals.create!(period: "day", target_seconds: 2.hours.to_i, languages: [], projects: [])

    visit my_settings_goals_path
    click_on "New goal"

    within_modal do
      click_on "2h"
      click_on "Create Goal"
    end

    assert_text "duplicate goal"
    assert_equal 1, @user.reload.goals.count
  end

  test "goals settings rejects creating more than five goals" do
    5.times do |index|
      @user.goals.create!(
        period: "day",
        target_seconds: (index + 1).hours.to_i,
        languages: [],
        projects: []
      )
    end

    visit my_settings_goals_path
    assert_text(/5 Active Goals/i)
    assert_button "New goal", disabled: true
    assert_equal 5, @user.reload.goals.count
  end
end
