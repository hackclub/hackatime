require "test_helper"

class WakatimeMirrorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Flipper.enable(:wakatime_imports_mirrors)
  end

  teardown do
    Flipper.disable(:wakatime_imports_mirrors)
  end

  test "creates mirror when imports and mirrors are enabled" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)

    assert_difference -> { user.reload.wakatime_mirrors.count }, 1 do
      post user_wakatime_mirrors_path(user), params: {
        wakatime_mirror: {
          endpoint_url: "https://wakapi.dev/api/compat/wakatime/v1",
          encrypted_api_key: "mirror-key"
        }
      }
    end

    assert_response :redirect
    assert_redirected_to my_settings_data_path
  end

  test "blocks mirror create when imports and mirrors are disabled" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)
    Flipper.disable(:wakatime_imports_mirrors)

    assert_no_difference -> { user.reload.wakatime_mirrors.count } do
      post user_wakatime_mirrors_path(user), params: {
        wakatime_mirror: {
          endpoint_url: "https://wakapi.dev/api/compat/wakatime/v1",
          encrypted_api_key: "mirror-key"
        }
      }
    end

    assert_response :redirect
    assert_redirected_to my_settings_data_path
  end
end
