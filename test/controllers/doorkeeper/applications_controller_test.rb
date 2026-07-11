require "test_helper"
require "json"
require "nokogiri"

class Doorkeeper::ApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "index redirects guests to signin" do
    get oauth_applications_path

    assert_response :redirect
    assert_redirected_to signin_path(continue: oauth_applications_path)
  end

  test "index renders only current user's applications in inertia payload" do
    user = User.create!(timezone: "UTC")
    other_user = User.create!(timezone: "UTC")
    user_application = create_application_for(user, name: "Owner App")
    create_application_for(other_user, name: "Other App")

    sign_in_as(user)
    get oauth_applications_path

    assert_response :success
    page = inertia_page

    assert_equal "OAuthApplications/Index", page["component"]
    assert_equal [ user_application.id ], page.dig("props", "applications").map { |application| application["id"] }
    assert_equal [ "Owner App" ], page.dig("props", "applications").map { |application| application["name"] }
  end

  test "show returns 404 for applications owned by another user" do
    user = User.create!(timezone: "UTC")
    other_user = User.create!(timezone: "UTC")
    other_user_application = create_application_for(other_user, name: "Private App")

    sign_in_as(user)
    get oauth_application_path(other_user_application)

    assert_response :not_found
  end

  test "show renders inertia payload with application details" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "Show App")

    sign_in_as(user)
    get oauth_application_path(application)

    assert_response :success
    page = inertia_page

    assert_equal "OAuthApplications/Show", page["component"]
    assert_equal application.id, page.dig("props", "application", "id")
    assert_equal application.name, page.dig("props", "application", "name")
  end

  test "show does not include client secret in inertia payload by default" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "Hidden Secret App")

    sign_in_as(user)
    get oauth_application_path(application)

    assert_response :success
    page = inertia_page

    assert_nil page.dig("props", "secret", "value")
    assert_equal false, page.dig("props", "secret", "just_rotated")
  end

  test "create persists owned application and redirects to show" do
    user = User.create!(timezone: "UTC")

    sign_in_as(user)
    assert_difference -> { OauthApplication.count }, 1 do
      post oauth_applications_path, params: {
        doorkeeper_application: valid_application_form_params(name: "Created App")
      }
    end

    created_application = OauthApplication.order(:created_at).last
    assert_equal user, created_application.owner
    assert_redirected_to oauth_application_url(created_application)
    assert flash[:application_secret].present?
  end

  test "show includes client secret once after creation" do
    user = User.create!(timezone: "UTC")

    sign_in_as(user)
    post oauth_applications_path, params: {
      doorkeeper_application: valid_application_form_params(name: "Created App")
    }

    follow_redirect!

    assert_response :success
    page = inertia_page

    assert page.dig("props", "secret", "value").present?
    assert_equal true, page.dig("props", "secret", "just_rotated")
  end

  test "create can persist HCA login redirect preference" do
    user = User.create!(timezone: "UTC")

    sign_in_as(user)
    post oauth_applications_path, params: {
      doorkeeper_application: valid_application_form_params(name: "HCA Login App").merge(redirect_to_hca_login: "1")
    }

    created_application = OauthApplication.order(:created_at).last
    assert created_application.redirect_to_hca_login?
  end

  test "create invalid re-renders inertia new with validation errors" do
    user = User.create!(timezone: "UTC")

    sign_in_as(user)
    post oauth_applications_path, params: {
      doorkeeper_application: valid_application_form_params(name: "")
    }

    assert_response :unprocessable_entity
    page = inertia_page

    assert_equal "OAuthApplications/New", page["component"]
    assert_not_empty page.dig("props", "errors", "full_messages")
  end

  test "create invalid json returns errors" do
    user = User.create!(timezone: "UTC")

    sign_in_as(user)
    post oauth_applications_path(format: :json), params: {
      doorkeeper_application: valid_application_form_params(name: "")
    }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_not_empty body["errors"]
  end

  test "update persists changes and redirects to show" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "Before")

    sign_in_as(user)
    patch oauth_application_path(application), params: {
      doorkeeper_application: valid_application_form_params(name: "After")
    }

    assert_redirected_to oauth_application_url(application)
    assert_equal "After", application.reload.name
  end

  test "update can persist HCA login redirect preference" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "Before")

    sign_in_as(user)
    patch oauth_application_path(application), params: {
      doorkeeper_application: valid_application_form_params(name: application.name).merge(redirect_to_hca_login: "1")
    }

    assert_redirected_to oauth_application_url(application)
    assert application.reload.redirect_to_hca_login?
  end

  test "update invalid re-renders inertia edit with validation errors" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "Valid Name")

    sign_in_as(user)
    patch oauth_application_path(application), params: {
      doorkeeper_application: valid_application_form_params(name: "")
    }

    assert_response :unprocessable_entity
    page = inertia_page

    assert_equal "OAuthApplications/Edit", page["component"]
    assert_not_empty page.dig("props", "errors", "name")
  end

  test "destroy removes application and redirects to index" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "Delete Me")

    sign_in_as(user)
    assert_difference -> { OauthApplication.count }, -1 do
      delete oauth_application_path(application)
    end

    assert_redirected_to oauth_applications_url
  end

  test "rotate_secret updates secret and redirects to show" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "Rotate Me")
    previous_secret = application.secret

    sign_in_as(user)
    post rotate_secret_oauth_application_path(application)

    assert_redirected_to oauth_application_url(application)
    assert_not_equal previous_secret, application.reload.secret
    assert flash[:application_secret].present?
    assert flash[:notice].present?
  end

  test "show includes client secret once after rotation" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "Rotate Me")

    sign_in_as(user)
    post rotate_secret_oauth_application_path(application)
    follow_redirect!

    assert_response :success
    page = inertia_page
    assert page.dig("props", "secret", "value").present?
    assert_equal true, page.dig("props", "secret", "just_rotated")
  end

  test "show json returns application data for owner" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "JSON App")

    sign_in_as(user)
    get oauth_application_path(application, format: :json)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal application.id, body["id"]
    assert_equal application.uid, body["uid"]
    assert_equal application.name, body["name"]
  end

  test "new form omits admin scope for non-admin users" do
    sign_in_as(User.create!(timezone: "UTC"))
    get new_oauth_application_path
    vals = scope_option_values
    assert_includes vals, "profile"
    assert_includes vals, "read"
    assert_not_includes vals, "admin"
  end

  test "new form includes admin scope for admin users" do
    sign_in_as(User.create!(timezone: "UTC", admin_level: :admin))
    get new_oauth_application_path
    assert_includes scope_option_values, "admin"
  end

  test "non-admin cannot create application with admin scope" do
    sign_in_as(User.create!(timezone: "UTC"))
    post oauth_applications_path, params: {
      doorkeeper_application: valid_application_form_params(name: "Sneaky").merge(scopes: %w[profile admin])
    }
    app = OauthApplication.order(:created_at).last
    assert_equal "Sneaky", app.name
    assert_not_includes app.scopes.to_a, "admin"
  end

  test "admin can create confidential application with admin scope" do
    sign_in_as(User.create!(timezone: "UTC", admin_level: :admin))
    post oauth_applications_path, params: {
      doorkeeper_application: valid_application_form_params(name: "Fraud Tool").merge(scopes: %w[profile admin])
    }
    assert_includes OauthApplication.order(:created_at).last.scopes.to_a, "admin"
  end

  test "admin scope requires confidential application" do
    sign_in_as(User.create!(timezone: "UTC", admin_level: :admin))
    assert_no_difference -> { OauthApplication.count } do
      post oauth_applications_path, params: {
        doorkeeper_application: valid_application_form_params(name: "Public Admin").merge(
          scopes: %w[profile admin], confidential: "0"
        )
      }
    end
    assert_response :unprocessable_entity
  end

  private

  def valid_application_params(name:)
    {
      name: name,
      redirect_uri: "https://example.com/callback",
      scopes: configured_scopes,
      confidential: "1"
    }
  end

  def valid_application_form_params(name:)
    valid_application_params(name: name).merge(scopes: configured_scopes.split)
  end

  def create_application_for(user, name:)
    user.oauth_applications.create!(valid_application_params(name: name))
  end

  def configured_scopes
    Doorkeeper.configuration.default_scopes.to_a.join(" ")
  end

  def scope_option_values
    inertia_page.dig("props", "scope_options").map { |s| s["value"] }
  end
end
