require "test_helper"

class Admin::OauthApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(timezone: "UTC", admin_level: :superadmin)
    @owner = User.create!(timezone: "UTC", display_name_override: "App Owner")
    @application = @owner.oauth_applications.create!(
      name: "Owner App",
      redirect_uri: "https://example.com/callback",
      scopes: "profile",
      confidential: true
    )
    sign_in_as(@admin)
  end

  test "index uses the shared applications component with admin context" do
    get admin_oauth_applications_path

    assert_response :success
    assert_inertia_component "OAuthApplications/Index"
    assert_equal true, inertia_page.dig("props", "admin_mode")
    application = inertia_page.dig("props", "applications").sole
    assert_equal @application.id, application["id"]
    assert_equal "App Owner", application.dig("owner", "display_name")
  end

  test "show uses the shared application component with admin actions" do
    get admin_oauth_application_path(@application)

    assert_response :success
    assert_inertia_component "OAuthApplications/Show"
    assert_equal true, inertia_page.dig("props", "admin_mode")
    assert_equal true, inertia_page.dig("props", "application", "can_toggle_verified")
    assert_equal "App Owner", inertia_page.dig("props", "application", "owner", "display_name")
  end

  test "edit uses the shared form and preserves admin verified-name override" do
    @application.update!(verified: true)

    get edit_admin_oauth_application_path(@application)

    assert_response :success
    assert_inertia_component "OAuthApplications/Edit"
    assert_equal true, inertia_page.dig("props", "admin_mode")
    assert_equal true, inertia_page.dig("props", "application", "verified")

    patch admin_oauth_application_path(@application), params: {
      oauth_application: {
        name: "Renamed App",
        redirect_uri: "https://example.com/new-callback",
        scopes: %w[profile read],
        confidential: "1",
        redirect_to_hca_login: "1"
      }
    }

    assert_redirected_to admin_oauth_application_path(@application)
    assert_equal "Renamed App", @application.reload.name
    assert_equal %w[profile read], @application.scopes.to_a
    assert @application.redirect_to_hca_login?
  end

  test "invalid update re-renders the shared form with errors" do
    patch admin_oauth_application_path(@application), params: {
      oauth_application: {
        name: "",
        redirect_uri: @application.redirect_uri,
        scopes: [ "profile" ],
        confidential: "1"
      }
    }

    assert_response :unprocessable_entity
    assert_inertia_component "OAuthApplications/Edit"
    assert_not_empty inertia_page.dig("props", "errors", "name")
  end
end
