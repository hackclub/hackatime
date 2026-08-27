require "test_helper"

class RackAttackTest < ActiveSupport::TestCase
  test "general throttle separates valid bearer credentials for the same user" do
    user = create(:user)
    first_token = create(:oauth_access_token, resource_owner_id: user.id, scopes: "read")
    second_token = create(:oauth_access_token, resource_owner_id: user.id, scopes: "read")

    assert_equal(
      "oauth_token:#{first_token.id}",
      discriminator_for(authorization: "Bearer #{first_token.token}")
    )
    assert_equal(
      "oauth_token:#{second_token.id}",
      discriminator_for(authorization: "Bearer #{second_token.token}")
    )
  end

  test "general throttle separates valid query credentials for the same user" do
    user = create(:user)
    first_key = create(:api_key, user: user)
    second_key = create(:api_key, user: user)

    path = "/api/hackatime/v1/users/current/heartbeats"
    assert_equal "api_key:#{first_key.id}", discriminator_for(path:, query: first_key.token)
    assert_equal "api_key:#{second_key.id}", discriminator_for(path:, query: second_key.token)
  end

  test "general throttle recognises valid basic credentials" do
    key = create(:api_key)
    authorization = "Basic #{Base64.strict_encode64(key.token)}"

    path = "/api/hackatime/v1/users/current/heartbeats"
    assert_equal "api_key:#{key.id}", discriminator_for(path:, authorization: authorization)
  end

  test "general throttle groups credentials sent over unsupported transports by IP" do
    key = create(:api_key)
    basic = "Basic #{Base64.strict_encode64(key.token)}"

    assert_equal "ip:198.51.100.20", discriminator_for(query: key.token)
    assert_equal "ip:198.51.100.20", discriminator_for(authorization: basic)
  end

  test "general throttle groups credentials invalid for the endpoint by IP" do
    oauth_token = create(:oauth_access_token, scopes: "profile")
    authorization = "Bearer #{oauth_token.token}"

    assert_equal "ip:198.51.100.20", discriminator_for(authorization: authorization)
  end

  test "general throttle groups invalid credentials by IP" do
    first = discriminator_for(authorization: "Bearer invalid-one")
    second = discriminator_for(authorization: "Bearer invalid-two")

    assert_equal "ip:198.51.100.20", first
    assert_equal first, second
  end

  test "general throttle groups anonymous requests by IP" do
    assert_equal "ip:198.51.100.20", discriminator_for
  end

  test "general throttle excludes assets" do
    assert_nil discriminator_for(path: "/assets/application.js")
  end

  private

  def discriminator_for(path: "/api/v1/authenticated/projects", authorization: nil, query: nil)
    path = "#{path}?api_key=#{query}" if query
    env = Rack::MockRequest.env_for(path, "REMOTE_ADDR" => "198.51.100.20")
    env["HTTP_AUTHORIZATION"] = authorization if authorization
    request = Rack::Attack::Request.new(env)

    Rack::Attack.throttles.fetch("general").block.call(request)
  end
end
