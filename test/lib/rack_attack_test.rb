require "test_helper"

class RackAttackTest < ActiveSupport::TestCase
  AUTHENTICATED_API_PATHS = [
    "/api/v1/authenticated/projects",
    "/api/v1/my/heartbeats",
    "/api/hackatime/v1/users/current/heartbeats",
    "/api/admin/v1/user/info"
  ].freeze

  test "general throttle excludes authenticated API paths" do
    AUTHENTICATED_API_PATHS.each { |path| assert_nil discriminator_for("general", path:), path }
  end

  test "post throttle excludes authenticated API paths" do
    AUTHENTICATED_API_PATHS.each { |path| assert_nil discriminator_for("posts by ip", path:, method: :post), path }
  end

  test "general throttle groups anonymous requests by IP" do
    assert_equal "198.51.100.20", discriminator_for("general")
  end

  test "post throttle groups anonymous requests by IP" do
    assert_equal "198.51.100.20", discriminator_for("posts by ip", method: :post)
  end

  test "general throttle excludes assets" do
    assert_nil discriminator_for("general", path: "/assets/application.js")
  end

  test "OAuth token exchanges are excluded from IP request throttles" do
    assert_nil discriminator_for("general", path: "/oauth/token", method: :post)
    assert_nil discriminator_for("posts by ip", path: "/oauth/token", method: :post)
  end

  test "OAuth token exchanges are grouped by client ID from the body" do
    assert_equal "client:app-uid",
      discriminator_for("oauth tokens by client", path: "/oauth/token", method: :post, params: { client_id: "app-uid" })
  end

  test "OAuth token exchanges are grouped by client ID from basic authentication" do
    authorization = ActionController::HttpAuthentication::Basic.encode_credentials("app-uid", "secret")

    assert_equal "client:app-uid",
      discriminator_for("oauth tokens by client", path: "/oauth/token", method: :post, authorization:)
  end

  test "OAuth token exchanges without a client ID are grouped by IP" do
    assert_equal "ip:198.51.100.20", discriminator_for("oauth tokens by client", path: "/oauth/token", method: :post)
    assert_equal "198.51.100.20", discriminator_for("oauth tokens by ip", path: "/oauth/token", method: :post)
  end

  private

  def discriminator_for(throttle, path: "/", method: :get, params: {}, authorization: nil)
    env = Rack::MockRequest.env_for(path, "REMOTE_ADDR" => "198.51.100.20", method: method.to_s.upcase, params:)
    env["HTTP_AUTHORIZATION"] = authorization if authorization
    request = Rack::Attack::Request.new(env)

    Rack::Attack.throttles.fetch(throttle).block.call(request)
  end
end
