# frozen_string_literal: true

require "test_helper"

class CustomDoorkeeperAuthorizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @oauth_app = create(:oauth_application, owner: @user,
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "profile",
      confidential: true
    )
  end

  test "new redirects unauthenticated user to sign in" do
    get "/oauth/authorize", params: authorization_params
    assert_response :redirect

    redirect_uri = URI.parse(response.location)
    assert_equal "/signin", redirect_uri.path
    assert_equal request.fullpath, Rack::Utils.parse_query(redirect_uri.query)["continue"]
  end

  test "new redirects unauthenticated user to HCA sign in when application requires it" do
    @oauth_app.update!(redirect_to_hca_login: true)

    get "/oauth/authorize", params: authorization_params
    assert_response :redirect

    redirect_uri = URI.parse(response.location)
    assert_equal "/auth/hca", redirect_uri.path
    assert_equal request.fullpath, Rack::Utils.parse_query(redirect_uri.query)["continue"]
  end

  test "new renders OAuthAuthorize/New for authorizable request" do
    sign_in_as(@user)
    # Delete any existing tokens so it doesn't skip authorization
    Doorkeeper::AccessToken.where(application: @oauth_app).delete_all

    get "/oauth/authorize", params: authorization_params
    assert_response :success

    assert_inertia_component "OAuthAuthorize/New"
    assert_equal @oauth_app.name, inertia.props["client_name"]
    assert_kind_of Array, inertia.props["scopes"]
    assert_predicate inertia.props.dig("form_data", "client_id"), :present?
  end

  test "new skips authorization when matching token exists" do
    sign_in_as(@user)
    create(:oauth_access_token,
      application: @oauth_app,
      resource_owner_id: @user.id,
      scopes: "profile",
      expires_in: 16.years
    )

    get "/oauth/authorize", params: authorization_params
    # Should redirect to callback with auth code, not render the form
    assert_response :redirect
    assert_match %r{example\.com/callback}, response.location
  end

  test "new renders error for invalid client_id" do
    sign_in_as(@user)
    get "/oauth/authorize", params: {
      client_id: "invalid",
      redirect_uri: "https://example.com/callback",
      response_type: "code",
      scope: "profile"
    }

    assert_inertia_component "OAuthAuthorize/Error"
    assert_predicate inertia.props["error_description"], :present?
  end

  test "new renders error for invalid client_id without a scope" do
    sign_in_as(@user)
    get "/oauth/authorize", params: {
      client_id: "invalid",
      redirect_uri: "https://example.com/callback",
      response_type: "code"
    }

    assert_response :success
    assert_inertia_component "OAuthAuthorize/Error"
    assert_predicate inertia.props["error_description"], :present?
  end

  test "show renders OAuthAuthorize/Show with code" do
    sign_in_as(@user)
    get "/oauth/authorize/native", params: { code: "test_code" }

    assert_response :success
    assert_inertia_component "OAuthAuthorize/Show"
    assert_inertia_props code: "test_code"
  end

  test "new denies non-admin users requesting admin scope" do
    enable_admin_scope!
    sign_in_as(@user)
    get "/oauth/authorize", params: authorization_params(scope: "admin")
    assert_response :forbidden
    assert_inertia_component "OAuthAuthorize/Error"
    assert_match(/admins/i, inertia.props["error_description"])
  end

  test "new denies unverified applications requesting admin scope" do
    enable_admin_scope!(verified: false)
    sign_in_as(create(:user, :admin))
    get "/oauth/authorize", params: authorization_params(scope: "admin")
    assert_response :forbidden
    assert_inertia_component "OAuthAuthorize/Error"
    assert_match(/verified applications/i, inertia.props["error_description"])
  end

  test "create denies unverified applications requesting admin scope" do
    enable_admin_scope!(verified: false)
    sign_in_as(create(:user, :admin))
    post "/oauth/authorize", params: authorization_params(scope: "admin")
    assert_response :forbidden
    assert_inertia_component "OAuthAuthorize/Error"
    assert_match(/verified applications/i, inertia.props["error_description"])
  end

  test "new denies applications without an explicitly configured admin scope" do
    @oauth_app.update!(scopes: "", verified: true)
    sign_in_as(create(:user, :admin))
    get "/oauth/authorize", params: authorization_params(scope: "admin")
    assert_response :forbidden
    assert_inertia_component "OAuthAuthorize/Error"
    assert_match(/configured with the admin scope/i, inertia.props["error_description"])
  end

  test "new denies public applications requesting admin scope" do
    enable_admin_scope!
    @oauth_app.update_column(:confidential, false)
    sign_in_as(create(:user, :admin))
    get "/oauth/authorize", params: authorization_params(scope: "admin")
    assert_response :forbidden
    assert_inertia_component "OAuthAuthorize/Error"
    assert_match(/confidential applications/i, inertia.props["error_description"])
  end

  test "new allows viewer requesting admin scope with warning prop" do
    enable_admin_scope!
    sign_in_as(create(:user, :viewer))
    get "/oauth/authorize", params: authorization_params(scope: "admin")
    assert_response :success
    assert_inertia_component "OAuthAuthorize/New"
    assert_inertia_props has_admin_scope: true
  end

  test "new allows admin requesting admin scope" do
    enable_admin_scope!
    sign_in_as(create(:user, :admin))
    get "/oauth/authorize", params: authorization_params(scope: "admin")
    assert_response :success
    assert_inertia_props has_admin_scope: true
  end

  test "create allows admin to authorize a verified confidential application with admin scope" do
    enable_admin_scope!
    sign_in_as(create(:user, :admin))
    post "/oauth/authorize", params: authorization_params(scope: "admin")
    assert_redirected_to %r{https://example\.com/callback\?code=}
  end

  private

  def enable_admin_scope!(verified: true)
    @oauth_app.update!(scopes: "profile admin", confidential: true, verified: verified)
    Doorkeeper::AccessToken.where(application: @oauth_app).delete_all
  end

  def authorization_params(scope: "profile")
    {
      client_id: @oauth_app.uid,
      redirect_uri: "https://example.com/callback",
      response_type: "code",
      scope: scope
    }
  end
end
