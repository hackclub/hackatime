require "test_helper"

class Api::Hackatime::V1::HackatimeControllerTest < ActionDispatch::IntegrationTest
  test "single text plain heartbeat normalizes hash payloads" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    payload = {
      entity: "src/main.rb",
      plugin: "vscode/1.0.0",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file"
    }

    assert_difference("Heartbeat.count", 1) do
      post "/api/hackatime/v1/users/current/heartbeats",
        params: payload.to_json,
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "text/plain"
        }
    end

    assert_response :accepted
    heartbeat = Heartbeat.order(:id).last
    assert_equal user.id, heartbeat.user_id
    assert_equal "vscode/1.0.0", heartbeat.user_agent
    assert_equal "coding", heartbeat.category
  end

  test "bulk heartbeat normalizes permitted params" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    payload = [ {
      entity: "src/main.rb",
      plugin: "zed/1.0.0",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file"
    } ]

    assert_difference("Heartbeat.count", 1) do
      post "/api/hackatime/v1/users/current/heartbeats.bulk",
        params: payload.to_json,
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "application/json"
        }
    end

    assert_response :created
    heartbeat = Heartbeat.order(:id).last
    assert_equal user.id, heartbeat.user_id
    assert_equal "zed/1.0.0", heartbeat.user_agent
    assert_equal "coding", heartbeat.category
  end
end
