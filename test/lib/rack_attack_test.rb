require "test_helper"

class RackAttackTest < ActiveSupport::TestCase
  CREDENTIAL_LIMITED_API_PATHS = [
    "/api/v1/authenticated/projects",
    "/api/v1/my/heartbeats",
    "/api/hackatime/v1/users/current/heartbeats",
    "/api/admin/v1/user/info",
    "/api/v1/stats",
    "/api/v1/users/lookup_email/someone@example.com",
    "/api/v1/users/someone/stats",
    "/api/v1/users/someone/projects/details"
  ].freeze

  IP_THROTTLES = [ "general", "posts by ip", "api requests" ].freeze

  test "IP throttles exclude API requests with credentials on credential-limited routes" do
    CREDENTIAL_LIMITED_API_PATHS.each do |path|
      IP_THROTTLES.each do |throttle|
        assert_nil discriminator_for(throttle, path:, method: :post, authorization: "Bearer token"), "#{throttle} #{path}"
      end
    end
  end

  test "IP throttles treat an api_key query parameter as credentials" do
    path = "/api/hackatime/v1/users/current/heartbeats?api_key=token"

    IP_THROTTLES.each { |throttle| assert_nil discriminator_for(throttle, path:, method: :post), throttle }
  end

  test "IP throttles limit credential-limited routes without credentials" do
    CREDENTIAL_LIMITED_API_PATHS.each do |path|
      IP_THROTTLES.each do |throttle|
        assert_equal "198.51.100.20", discriminator_for(throttle, path:, method: :post), "#{throttle} #{path}"
      end
    end
  end

  test "IP throttles limit other API routes with credentials" do
    [ "/api/v1/users/someone/trust_factor", "/api/v1/leaderboard", "/api/internal/revoke" ].each do |path|
      assert_equal "198.51.100.20", discriminator_for("api requests", path:, authorization: "Bearer token"), path
    end
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

  test "OAuth token exchanges are grouped by client ID from the body and IP" do
    assert_equal "client:app-uid:198.51.100.20",
      discriminator_for("oauth tokens by client", path: "/oauth/token", method: :post, params: { client_id: "app-uid" })
  end

  test "OAuth token exchanges are grouped by client ID from basic authentication and IP" do
    authorization = ActionController::HttpAuthentication::Basic.encode_credentials("app-uid", "secret")

    assert_equal "client:app-uid:198.51.100.20",
      discriminator_for("oauth tokens by client", path: "/oauth/token", method: :post, authorization:)
  end

  test "OAuth token exchanges from other IPs do not share an application's allowance" do
    params = { client_id: "app-uid" }

    refute_equal discriminator_for("oauth tokens by client", path: "/oauth/token", method: :post, params:),
      discriminator_for("oauth tokens by client", path: "/oauth/token", method: :post, params:, remote_addr: "203.0.113.50")
  end

  test "OAuth token exchanges without a client ID are grouped by IP" do
    assert_equal "ip:198.51.100.20", discriminator_for("oauth tokens by client", path: "/oauth/token", method: :post)
    assert_equal "198.51.100.20", discriminator_for("oauth tokens by ip", path: "/oauth/token", method: :post)
  end

  private

  def discriminator_for(throttle, path: "/", method: :get, params: {}, authorization: nil, remote_addr: "198.51.100.20")
    env = Rack::MockRequest.env_for(path, "REMOTE_ADDR" => remote_addr, method: method.to_s.upcase, params:)
    env["HTTP_AUTHORIZATION"] = authorization if authorization
    request = Rack::Attack::Request.new(env)

    Rack::Attack.throttles.fetch(throttle).block.call(request)
  end
end
