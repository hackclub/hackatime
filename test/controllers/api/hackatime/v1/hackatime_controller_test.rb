require "test_helper"
require "stringio"

class Api::Hackatime::V1::HackatimeControllerTest < ActionDispatch::IntegrationTest
  test "single text plain heartbeat normalizes hash payloads" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    payload = {
      dependencies: [ "rails", "pg" ],
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
    assert_equal [ "rails", "pg" ], heartbeat.dependencies
  end

  test "single heartbeat stores the Cloudflare JA4 header" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")
    ja4 = "t13d1516h2_8daaf6152771_02713d6af862"

    assert_difference([ "Heartbeat.count", "Ja4.count" ], 1) do
      post "/api/hackatime/v1/users/current/heartbeats",
        params: {
          entity: "src/main.rb",
          project: "hackatime",
          time: Time.current.to_f,
          type: "file"
        }.to_json,
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "text/plain",
          "CF-JA4" => ja4
        }
    end

    assert_response :accepted
    assert_equal ja4, Heartbeat.order(:id).last.ja4.fingerprint
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
      project: "hackatime",
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

  test "single heartbeat ignores unknown fields and preserves AI telemetry" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    payload = {
      entity: "src/main.rb",
      plugin: "vscode/1.131.0 vscode-wakatime/29.0.3",
      project: "hackatime",
      time: Time.current.to_f,
      type: "file",
      raw_data: '{"some": "data"}',
      ai_model: "gpt/5.6",
      ai_session: "session-123",
      ai_subscription_plan: "pro",
      ai_input_tokens: 1_000,
      ai_output_tokens: 250,
      ai_prompt_length: 80,
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
    assert_equal "gpt/5.6", heartbeat.ai_model
    assert_equal "session-123", heartbeat.ai_session
    assert_equal "pro", heartbeat.ai_subscription_plan
    assert_equal 1_000, heartbeat.ai_input_tokens
    assert_equal 250, heartbeat.ai_output_tokens
    assert_equal 80, heartbeat.ai_prompt_length
    assert_equal 5, heartbeat.ai_line_changes
    assert_equal 10, heartbeat.human_line_changes
  end

  test "bulk heartbeat ignores unknown fields and preserves AI telemetry" do
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
        ai_session: "session-456",
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
    assert_equal "session-456", heartbeat.ai_session
    assert_equal 3, heartbeat.ai_line_changes
    assert_equal 7, heartbeat.human_line_changes
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

    log_output = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_output)

    # Second request with same data should not create a duplicate or log a uniqueness error
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
    response_heartbeat = JSON.parse(response.body)
    assert_equal heartbeat.id, response_heartbeat.fetch("id")
    assert_equal "src/main.rb", response_heartbeat.fetch("entity")
    assert_no_match(/RecordNotUnique|duplicate key|unique/i, log_output.string)
  ensure
    Rails.logger = previous_logger if previous_logger
  end

  test "bulk heartbeat normalizes permitted params" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    payload = [ {
      dependencies: [ "rack", "puma" ],
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
    assert_equal [ "rack", "puma" ], heartbeat.dependencies
  end

  test "single heartbeat returns unprocessable entity when ingestion fails" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    assert_no_difference("Heartbeat.count") do
      post "/api/hackatime/v1/users/current/heartbeats",
        params: { entity: "src/main.rb", time: 2026, type: "file" }.to_json,
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "text/plain"
        }
    end

    assert_response :unprocessable_entity
    assert_equal "HeartbeatIngest::InvalidHeartbeatTime", JSON.parse(response.body)["type"]
  end

  test "bulk text plain heartbeat rejects a non-array payload" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    assert_no_difference("Heartbeat.count") do
      post "/api/hackatime/v1/users/current/heartbeats.bulk",
        params: { entity: "src/main.rb", time: Time.current.to_f, type: "file" }.to_json,
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "text/plain"
        }
    end

    assert_response :bad_request
  end

  test "bulk heartbeat reports non-object array items without discarding valid items" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    assert_difference("Heartbeat.count", 1) do
      post "/api/hackatime/v1/users/current/heartbeats.bulk",
        params: [ "not-a-heartbeat", { entity: "src/main.rb", time: Time.current.to_f, type: "file" } ].to_json,
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "text/plain"
        }
    end

    assert_response :created
    responses = JSON.parse(response.body).fetch("responses")
    assert_equal 422, responses.first.last
    assert_equal 201, responses.last.last
  end

  test "single text plain heartbeat rejects a scalar payload" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    assert_no_difference("Heartbeat.count") do
      post "/api/hackatime/v1/users/current/heartbeats",
        params: "42",
        headers: {
          "Authorization" => "Bearer #{api_key.token}",
          "CONTENT_TYPE" => "text/plain"
        }
    end

    assert_response :bad_request
  end

  test "status bar accepts API keys with Basic authentication" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    get "/api/hackatime/v1/users/current/statusbar/today",
      headers: { "Authorization" => "Basic #{Base64.strict_encode64(api_key.token)}" }

    assert_response :success
  end

  test "status bar accepts API keys from the query string" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    get "/api/hackatime/v1/users/current/statusbar/today", params: { api_key: api_key.token }

    assert_response :success
  end

  test "status bar does not accept OAuth access tokens" do
    user = User.create!(timezone: "UTC")
    access_token = create_oauth_access_token(user)

    get "/api/hackatime/v1/users/current/statusbar/today",
      headers: { "Authorization" => "Bearer #{access_token.token}" }

    assert_response :unauthorized
  end

  test "malformed authorization header does not fall through to query API key" do
    user = User.create!(timezone: "UTC")
    api_key = user.api_keys.create!(name: "primary")

    get "/api/hackatime/v1/users/current/statusbar/today",
      params: { api_key: api_key.token },
      headers: { "Authorization" => "Bearer" }

    assert_response :unauthorized
  end

  private

  def create_oauth_access_token(user)
    application = user.oauth_applications.create!(
      name: "Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "profile read",
      confidential: true
    )

    Doorkeeper::AccessToken.create!(
      application: application,
      resource_owner_id: user.id,
      scopes: "profile read",
      expires_in: 16.years
    )
  end
end
