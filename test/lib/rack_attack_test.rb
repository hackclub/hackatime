require "test_helper"

class RackAttackTest < ActiveSupport::TestCase
  test "general throttle separates valid OAuth credentials for the same user" do
    user = create(:user)
    first_token = create(:oauth_access_token, resource_owner_id: user.id)
    second_token = create(:oauth_access_token, resource_owner_id: user.id)

    assert_equal(
      "oauth_token:#{first_token.id}",
      discriminator_for(authorization: "Bearer #{first_token.token}")
    )
    assert_equal(
      "oauth_token:#{second_token.id}",
      discriminator_for(authorization: "Bearer #{second_token.token}")
    )
  end

  test "general throttle groups invalid credentials by IP" do
    first = discriminator_for(authorization: "Bearer invalid-one")
    second = discriminator_for(authorization: "Bearer invalid-two")

    assert_equal "198.51.100.20", first
    assert_equal first, second
  end

  test "general throttle groups anonymous requests by IP" do
    assert_equal "198.51.100.20", discriminator_for
  end

  test "general throttle excludes assets" do
    assert_nil discriminator_for(path: "/assets/application.js")
  end

  private

  def discriminator_for(path: "/api/v1/authenticated/projects", authorization: nil)
    env = Rack::MockRequest.env_for(path, "REMOTE_ADDR" => "198.51.100.20")
    env["HTTP_AUTHORIZATION"] = authorization if authorization
    request = Rack::Attack::Request.new(env)

    Rack::Attack.throttles.fetch("general").block.call(request)
  end
end
