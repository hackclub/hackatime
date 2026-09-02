require "test_helper"

class Admin::TimelineControllerTest < ActionDispatch::IntegrationTest
  test "show renders for admins" do
    admin = create(:user, :admin)
    sign_in_as(admin)

    get admin_timeline_path

    assert_response :success
    assert_inertia_component "Admin/Timeline"
  end

  test "show includes the current admin with an empty timeline when no users are selected" do
    admin = create(:user, :admin)
    sign_in_as(admin)

    get admin_timeline_path

    assert_response :success
    assert_equal [ admin.id ], inertia.props.fetch("selected_users").pluck("id")
    assert_equal [ admin.id ], inertia.props.fetch("columns").pluck("user").pluck("id")
    assert_empty inertia.props.dig("columns", 0, "spans")
  end

  test "show limits the browser timeline to 20 requested users plus the current admin" do
    admin = create(:user, :admin)
    requested_users = create_list(:user, TimelineService::MAX_REQUESTED_TIMELINE_USERS + 2)
    sign_in_as(admin)

    get admin_timeline_path(user_ids: requested_users.map(&:id).join(","))

    assert_response :success
    selected_user_ids = inertia.props.fetch("selected_users").pluck("id")
    assert_equal TimelineService::MAX_TIMELINE_USERS, selected_user_ids.size
    assert_equal [ admin.id, *requested_users.first(TimelineService::MAX_REQUESTED_TIMELINE_USERS).map(&:id) ], selected_user_ids
  end

  test "show falls back to today for a malformed date param" do
    admin = create(:user, :admin)
    sign_in_as(admin)

    get admin_timeline_path(date: "not-a-date")

    assert_response :success
    assert_equal Time.current.to_date.to_s, inertia.props["date"]
  end

  test "search_users returns a bare empty array for a blank query" do
    admin = create(:user, :admin)
    sign_in_as(admin)

    get "/admin/timeline/search_users", params: { query: "" }

    assert_response :success
    assert_equal [], response.parsed_body
  end
end
