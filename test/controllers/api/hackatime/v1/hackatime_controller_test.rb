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

  test "single heartbeat resolves <<LAST_LANGUAGE>> from existing heartbeats" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")
    # Seed a prior heartbeat with a known language
    user.heartbeats.create!(
      entity: "src/old.rb",
      type: "file",
      category: "coding",
      time: 1.hour.ago.to_f,
      language: "Ruby",
      source_type: :direct_entry
    )

    payload = {
      entity: "src/main.rb",
      plugin: "vscode/1.0.0",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file",
      language: "<<LAST_LANGUAGE>>"
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
    assert_equal "Ruby", heartbeat.language
  end

  test "bulk heartbeat resolves <<LAST_LANGUAGE>> from previous heartbeat in same batch" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    now = Time.current.to_f
    payload = [
      {
        entity: "src/first.rb",
        plugin: "vscode/1.0.0",
        project: "hackatime",
        time: now - 2,
        type: "file",
        language: "Python"
      },
      {
        entity: "src/second.rb",
        plugin: "vscode/1.0.0",
        project: "hackatime",
        time: now - 1,
        type: "file",
        language: "<<LAST_LANGUAGE>>"
      }
    ]

    assert_difference("Heartbeat.count", 2) do
      post "/api/hackatime/v1/users/current/heartbeats.bulk",
        params: payload.to_json,
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "application/json"
        }
    end

    assert_response :created
    heartbeats = Heartbeat.order(:id).last(2)
    assert_equal "Python", heartbeats.first.language
    assert_equal "Python", heartbeats.last.language
  end

  test "single heartbeat with <<LAST_LANGUAGE>> and no prior heartbeats infers language from extension" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    payload = {
      entity: "src/main.rb",
      plugin: "vscode/1.0.0",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file",
      language: "<<LAST_LANGUAGE>>"
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
    assert_equal "Ruby", heartbeat.language
  end

  test "single heartbeat ignores unknown fields like raw_data and ai_line_changes" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    payload = {
      entity: "src/main.rb",
      plugin: "vscode/1.131.0 vscode-wakatime/29.0.3",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file",
      raw_data: '{"some": "data"}',
      ai_line_changes: 5,
      human_line_changes: 10,
      completely_bogus_field: "should be ignored"
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
    assert_equal "src/main.rb", heartbeat.entity
    assert_equal "hackatime", heartbeat.project
  end

  test "bulk heartbeat ignores unknown fields like raw_data and ai_line_changes" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    payload = [
      {
        entity: "src/first.rb",
        plugin: "vscode/1.131.0 vscode-wakatime/29.0.3",
        project: "hackatime",
        time: Time.current.to_f,
        type: "file",
        raw_data: '{"some": "data"}',
        ai_line_changes: 3,
        human_line_changes: 7
      }
    ]

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
    assert_equal "src/first.rb", heartbeat.entity
    assert_equal "hackatime", heartbeat.project
  end

  test "duplicate heartbeat with different ip returns existing record" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    payload = {
      entity: "src/main.rb",
      plugin: "vscode/1.0.0",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file"
    }

    # First request creates the heartbeat
    assert_difference("Heartbeat.count", 1) do
      post "/api/hackatime/v1/users/current/heartbeats",
        params: payload.to_json,
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "text/plain",
          "CF-Connecting-IP" => "203.0.113.10"
        }
    end
    assert_response :accepted
    heartbeat = Heartbeat.order(:id).last

    # Second request with same data should not create a duplicate
    assert_no_difference("Heartbeat.count") do
      post "/api/hackatime/v1/users/current/heartbeats",
        params: payload.to_json,
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "text/plain",
          "CF-Connecting-IP" => "203.0.113.20"
        }
    end
    assert_response :accepted
    assert_equal heartbeat.id, JSON.parse(response.body)["id"]
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
