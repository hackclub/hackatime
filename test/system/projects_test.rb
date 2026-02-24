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
