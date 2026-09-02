require "test_helper"

class SettingsEditorsControllerTest < ActionDispatch::IntegrationTest
  test "show provides extension text type options" do
    user = create(:user)
    sign_in_as(user)

    get my_settings_editors_path

    assert_response :success
    assert_inertia_component "Users/Settings/Editors"
    assert_equal [ "extension_text_types" ], inertia.props.fetch("options").keys
    assert_equal [
      { "label" => "Simple text", "value" => "simple_text" },
      { "label" => "Clock emoji", "value" => "clock_emoji" },
      { "label" => "Compliment text", "value" => "compliment_text" }
    ], inertia.props.dig("options", "extension_text_types")
  end
end
