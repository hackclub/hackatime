require "application_system_test_case"

class ProjectsTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  test "shows active projects by default and archived projects when toggled" do
    create_project_heartbeats(@user, "active-project", started_at: 2.days.ago.noon)

    archived_mapping = @user.project_repo_mappings.create!(project_name: "archived-project")
    archived_mapping.archive!
    create_project_heartbeats(@user, "archived-project", started_at: 2.days.ago.change(hour: 14))
    DashboardRollupRefreshService.new(user: @user).call

    visit my_projects_path

    assert_text "active-project"
    assert_no_text "archived-project"

    click_on "Archived"
    assert_text "archived-project"
    assert_no_text "active-project"

    click_on "Active"
    assert_text "active-project"
    assert_no_text "archived-project"
  end

  test "filters projects by time period" do
    create_project_heartbeats(@user, "recent-project", started_at: 2.days.ago.noon)
    create_project_heartbeats(@user, "older-project", started_at: 20.days.ago.noon)

    last_7_days_path = my_projects_path(interval: "last_7_days")
    assert_includes last_7_days_path, "interval=last_7_days"
    visit last_7_days_path
    assert_includes page.current_url, "interval=last_7_days"
    assert_text "recent-project"
    assert_no_text "older-project"

    last_30_days_path = my_projects_path(interval: "last_30_days")
    assert_includes last_30_days_path, "interval=last_30_days"
    visit last_30_days_path
    assert_includes page.current_url, "interval=last_30_days"
    assert_text "recent-project"
    assert_text "older-project"

    from = 21.days.ago.to_date.iso8601
    to = 19.days.ago.to_date.iso8601

    custom_path = my_projects_path(interval: "custom", from: from, to: to)
    assert_includes custom_path, "interval=custom"
    visit custom_path
    assert_includes page.current_url, "interval=custom"
    assert_text "older-project"
    assert_no_text "recent-project"
  end

  test "finds projects with the browser find shortcut" do
    create_project_heartbeats(@user, "alpha-project", started_at: 2.days.ago.noon)
    create_project_heartbeats(@user, "beta-project", started_at: 2.days.ago.change(hour: 14))
    DashboardRollupRefreshService.new(user: @user).call

    visit my_projects_path
    assert_text "alpha-project"
    assert_text "beta-project"
    assert_selector "#project-filter[placeholder='Search projects']"

    page.driver.browser.action.key_down(:control).send_keys("f").key_up(:control).perform

    assert_selector "[role='search'][aria-label='Find projects']"
    fill_in "Find projects", with: "alpha"
    assert_text "1/1"
    assert_text "alpha-project"
    assert_selector "mark.bg-yellow", text: "alpha"
    assert_no_text "beta-project"

    find("#project-search").send_keys(:escape)

    assert_no_selector "[role='search'][aria-label='Find projects']"
    assert_text "alpha-project"
    assert_text "beta-project"
  end

  test "opens projects whose names contain reserved URL characters" do
    project_name = "folder/café ?# 100%25"
    create_project_heartbeats(@user, project_name, started_at: 2.days.ago.noon)
    DashboardRollupRefreshService.new(user: @user).call

    visit my_projects_path
    project_link = find(%(a[aria-label="View #{project_name}"]))
    assert_includes project_link[:href], "folder%2Fcaf%C3%A9%20%3F%23%20100%2525"
    visit project_link[:href]

    assert_selector "h1", text: project_name, exact_text: true
  end

  private

  def create_project_heartbeats(user, project_name, started_at:)
    user.project_repo_mappings.find_or_create_by!(project_name: project_name)

    Heartbeat.create!(
      user: user,
      project: project_name,
      category: "coding",
      time: started_at.to_i,
      source_type: :test_entry
    )
    Heartbeat.create!(
      user: user,
      project: project_name,
      category: "coding",
      time: (started_at + 30.minutes).to_i,
      source_type: :test_entry
    )
  end
end
