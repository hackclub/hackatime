require "application_system_test_case"
require_relative "test_helpers"

class GoalsSettingsTest < ApplicationSystemTestCase
  include SettingsSystemTestHelpers

  setup do
    @user = create(:user, :with_email)
    sign_in_as(@user)
  end

  test "goals settings can create edit and delete goal" do
    create_goal_options
    visit my_settings_goals_path

    assert_text(/0 Active Goals/i)
    click_on "New goal"

    within("[role='dialog']") do
      click_on "2h"
    end
    select_goal_scope "Languages (optional)", "Ruby"
    select_goal_scope "Projects (optional)", "alpha"
    within("[role='dialog']") do
      click_on "Create Goal"
    end

    assert_text "Goal created."
    assert_text(/1 Active Goal/i)
    assert_text "Daily: 2h"
    assert_text "Languages: Ruby AND Projects: alpha"

    goal = @user.reload.goals.first
    assert_equal 2.hours.to_i, goal.target_seconds
    assert_equal [ "Ruby" ], goal.languages
    assert_equal [ "alpha" ], goal.projects

    click_on "Edit"
    within("[role='dialog']") do
      click_on "30m"
      all("button", text: "×", exact_text: true).each(&:click)
      click_on "Update Goal"
    end

    assert_text "Goal updated."
    assert_text "Daily: 30m"

    goal.reload
    assert_equal 30.minutes.to_i, goal.target_seconds
    assert_equal [], goal.languages
    assert_equal [], goal.projects

    click_on "Delete"
    assert_text "Goal deleted."
    assert_text(/0 Active Goals/i)
    assert_equal 0, @user.reload.goals.count
  end

  test "goals settings keeps the normalized form open after a duplicate goal response" do
    create_goal_options
    create(:goal,
      user: @user,
      period: "day",
      target_seconds: 2.hours.to_i,
      languages: [ "Python", "Ruby" ],
      projects: [ "alpha", "beta" ]
    )

    visit my_settings_goals_path
    click_on "New goal"

    within("[role='dialog']") do
      click_on "2h"
    end
    select_goal_scope "Languages (optional)", "Ruby", "Python"
    select_goal_scope "Projects (optional)", "beta", "alpha"
    within("[role='dialog']") do
      click_on "Create Goal"
    end

    assert_text "duplicate goal"
    assert_selector "[role='dialog']"

    within("[role='dialog']") do
      assert_button "Create Goal"
      assert_equal [ "", "Python", "Ruby" ], hidden_goal_values("languages")
      assert_equal [ "", "alpha", "beta" ], hidden_goal_values("projects")
    end

    assert_equal 1, @user.reload.goals.count
  end

  test "goals settings rejects creating more than five goals" do
    5.times do |index|
      create(
        :goal,
        user: @user,
        period: "day",
        target_seconds: (index + 1).hours.to_i,
        languages: [],
        projects: []
      )
    end

    assert_settings_page(
      path: my_settings_goals_path,
      marker_text: "Programming Goals"
    )

    assert_text(/5 Active Goals/i)
    assert_button "New goal", disabled: true
    assert_equal 5, @user.reload.goals.count
  end

  private

  def create_goal_options
    create(:heartbeat,
      user: @user,
      language: "Python",
      project: "alpha",
      time: 2.minutes.ago.to_f
    )
    create(:heartbeat,
      user: @user,
      language: "Ruby",
      project: "beta",
      time: 1.minute.ago.to_f
    )
  end

  def select_goal_scope(label, *values)
    find("p", text: label, exact_text: true)
      .find(:xpath, "..")
      .find(".group")
      .click

    values.each do |value|
      find(".dashboard-select-popover button", text: value, exact_text: true).click
    end

    page.send_keys(:escape)
  end

  def hidden_goal_values(field)
    all("input[name='goal[#{field}][]']", visible: :all).map { |input| input[:value] }
  end
end
