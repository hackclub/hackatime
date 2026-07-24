require "application_system_test_case"

class ProjectsWithUnsafeNamesTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(timezone: "UTC")
    sign_in_as(@user)
  end

  # Each unsafe character that previously broke the Projects page or archive
  # action. The fix URL-encodes the project name on the client before passing
  # it to `js_from_routes`' path helpers, so the card stays clickable and the
  # server receives the original name after Rails decodes the path param.
  UNSAFE_NAMES = [
    "myproject:R",     # #1414 — colon + letter crashes js_from_routes
    "foo:Hello",       # another colon + letter variant
    ":bar",            # leading colon
    "a:b:c",           # multiple colons
    "slash/project",   # #1442 — slash breaks Rails routing on archive
    "foo?bar",         # question mark (query delimiter)
    "foo#bar",         # hash (fragment delimiter)
    "foo%bar",         # literal percent (would double-decode with old CGI.unescape)
    "Aritmética",      # unicode (should always work)
    "normal-project"   # control — normal name
  ].freeze

  test "projects page renders all unsafe-named projects as clickable cards" do
    UNSAFE_NAMES.each do |name|
      create_project_heartbeats(@user, name, started_at: 2.days.ago.noon)
    end
    DashboardRollupRefreshService.new(user: @user).call

    visit my_projects_path

    # Every project should render — no card should crash the virtualizer.
    UNSAFE_NAMES.each { |name| assert_text name }

    # None should show the "broken name" badge — URL-unsafe chars are not
    # structurally invalid, they're handled by URL-encoding on the client.
    assert_no_text "Time can't be used in Hack Club programs"

    # Each card should have a clickable link overlay with the URL-encoded
    # project name in the href.
    UNSAFE_NAMES.each do |name|
      link = find("a[aria-label='View #{name}']", wait: 5)
      encoded = URI.encode_www_form_component(name)
      assert_includes link[:href], encoded,
        "expected link href for #{name.inspect} to contain #{encoded}, got #{link[:href]}"
    end
  end

  test "clicking a colon-named project navigates to its detail page (#1414)" do
    create_project_heartbeats(@user, "myproject:R", started_at: 2.days.ago.noon)
    DashboardRollupRefreshService.new(user: @user).call

    visit my_projects_path

    assert_text "myproject:R"
    assert_no_text "Time can't be used in Hack Club programs"

    link = find("a[aria-label='View myproject:R']")
    assert_includes link[:href], "myproject%3AR"

    visit link[:href]
    assert_text "myproject:R"
  end

  test "clicking a slash-named project navigates to its detail page (#1442)" do
    create_project_heartbeats(@user, "slash/project", started_at: 2.days.ago.noon)
    DashboardRollupRefreshService.new(user: @user).call

    visit my_projects_path

    assert_text "slash/project"
    assert_no_text "Time can't be used in Hack Club programs"

    link = find("a[aria-label='View slash/project']")
    assert_includes link[:href], "slash%2Fproject"

    visit link[:href]
    assert_text "slash/project"
  end

  test "archiving a slash-named project works (#1442)" do
    @user.project_repo_mappings.create!(project_name: "slash/project")
    create_project_heartbeats(@user, "slash/project", started_at: 2.days.ago.noon)
    DashboardRollupRefreshService.new(user: @user).call

    visit my_projects_path

    assert_text "slash/project"

    within find("article", text: "slash/project") do
      find("button[title='Archive project']").click
    end

    within find("div[role='dialog']", wait: 5) do
      click_on "Archive project"
    end

    assert_text "Away it goes!"
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
