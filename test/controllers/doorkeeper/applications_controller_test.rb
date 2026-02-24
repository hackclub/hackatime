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
    assert_equal rotate_secret_oauth_application_path(application), page.dig("props", "application", "rotate_secret_path")
  end

  test "create persists owned application and redirects to show" do
    user = User.create!(timezone: "UTC")

    sign_in_as(user)
    assert_difference -> { OauthApplication.count }, 1 do
      post oauth_applications_path, params: {
        doorkeeper_application: valid_application_params(name: "Created App")
      }
    end

    created_application = OauthApplication.order(:created_at).last
    assert_equal user, created_application.owner
    assert_redirected_to oauth_application_url(created_application)
    assert flash[:application_secret].present?
  end

  test "create invalid re-renders inertia new with validation errors" do
    user = User.create!(timezone: "UTC")

    sign_in_as(user)
    post oauth_applications_path, params: {
      doorkeeper_application: valid_application_params(name: "")
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
      doorkeeper_application: valid_application_params(name: "")
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
      doorkeeper_application: { name: "After" }
    }

    assert_redirected_to oauth_application_url(application)
    assert_equal "After", application.reload.name
  end

  test "update invalid re-renders inertia edit with validation errors" do
    user = User.create!(timezone: "UTC")
    application = create_application_for(user, name: "Valid Name")

    sign_in_as(user)
    patch oauth_application_path(application), params: {
      doorkeeper_application: { name: "" }
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

  private

  def valid_application_params(name:)
    {
      name: name,
      redirect_uri: "https://example.com/callback",
      scopes: configured_scopes,
      confidential: "1"
    }
  end

  def create_application_for(user, name:)
    user.oauth_applications.create!(valid_application_params(name: name))
  end

  def configured_scopes
    Doorkeeper.configuration.default_scopes.to_a.join(" ")
  end
end
