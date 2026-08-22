require "test_helper"

class Admin::TimelineControllerTest < ActionDispatch::IntegrationTest
  test "show renders for admins" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    sign_in_as(admin)

    get admin_timeline_path

    assert_response :success
    assert_inertia_component "Admin/Timeline"
  end

  test "show falls back to today for a malformed date param" do
    admin = User.create!(timezone: "UTC", admin_level: :admin)
    sign_in_as(admin)

    get admin_timeline_path(date: "not-a-date")

    assert_response :success
    assert_equal Time.current.to_date.to_s, inertia_page.dig("props", "date")
  end
end
