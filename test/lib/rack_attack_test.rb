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

  private

  def discriminator_for(throttle, path: "/", method: :get)
    env = Rack::MockRequest.env_for(path, "REMOTE_ADDR" => "198.51.100.20", method: method.to_s.upcase)
    request = Rack::Attack::Request.new(env)

    Rack::Attack.throttles.fetch(throttle).block.call(request)
  end
end
