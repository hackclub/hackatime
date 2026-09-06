require "test_helper"

class ApiKeySelectionControllerTest < ActionDispatch::IntegrationTest
  test "user-facing controllers return the same canonical key when multiple exist" do
    user = create(:user, :with_email)
    create(:api_key, user: user, name: "Desktop")
    canonical_key = create(:api_key, user: user, name: "Hackatime key")
    create(:api_key, user: user, name: "Laptop")
    sign_in_as(user)

    get api_key_path
    api_key_page_token = inertia.props["api_key"]

    get setup_path
    setup_guide_token = inertia.props["current_user_api_key"]

    get my_settings_setup_path
    settings_token = inertia.props.dig("config_file", "api_key")

    access_token = create(:oauth_access_token,
      application: create(:oauth_application, owner: user),
      resource_owner_id: user.id
    )
    get "/api/v1/authenticated/api_keys", headers: {
      "Authorization" => "Bearer #{access_token.token}"
    }
    api_token = response.parsed_body["token"]

    assert_equal [ canonical_key.token ] * 4,
      [ api_key_page_token, setup_guide_token, settings_token, api_token ]
    assert_equal 3, user.api_keys.count
  end
end
