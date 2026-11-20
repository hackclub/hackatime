require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

class HeartbeatImportDumpClientTest < ActiveSupport::TestCase
  test "valid_wakatime_download_url? only accepts wakatime s3 links over https" do
    assert HeartbeatImportDumpClient.valid_wakatime_download_url?("https://wakatime.s3.amazonaws.com/export.json?signature=abc")
    assert_not HeartbeatImportDumpClient.valid_wakatime_download_url?("http://wakatime.s3.amazonaws.com/export.json")
    assert_not HeartbeatImportDumpClient.valid_wakatime_download_url?("https://wakatime.com/export.json")
  end

  test "request_dump sends basic auth with the raw api key" do
    client = HeartbeatImportDumpClient.new(source_kind: :hackatime_v1_dump, api_key: "secret-key")

    stub = stub_request(:post, "https://waka.hackclub.com/api/v1/users/current/data_dumps")
      .with(
        headers: {
          "Authorization" => "Basic #{Base64.strict_encode64("secret-key")}",
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        },
        body: { type: "heartbeats", email_when_finished: false }.to_json
      )
      .to_return(
        status: 201,
        body: {
          data: {
            id: "dump-123",
            status: "Processing",
            percent_complete: 0,
            type: "heartbeats",
            is_processing: true,
            is_stuck: false,
            has_failed: false
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    response = client.request_dump

    assert_requested stub
    assert_equal "dump-123", response[:id]
  end

  test "request_dump resumes the active hackatime v1 dump when the provider says one is already in progress" do
    client = HeartbeatImportDumpClient.new(source_kind: :hackatime_v1_dump, api_key: "secret-key")

    stub_request(:post, "https://waka.hackclub.com/api/v1/users/current/data_dumps")
      .to_return(
        status: 400,
        body: { error: "a data export is already in progress, please wait for it to complete" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://waka.hackclub.com/api/v1/users/current/data_dumps")
      .with(
        headers: {
          "Authorization" => "Basic #{Base64.strict_encode64("secret-key")}",
          "Accept" => "application/json",
          "Content-Type" => "application/json"
        }
      )
      .to_return(
        status: 200,
        body: {
          data: [
            {
              id: "dump-456",
              status: "Pending…",
              percent_complete: 0,
              type: "heartbeats",
              is_processing: true,
              is_stuck: false,
              has_failed: false
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    response = client.request_dump

    assert_equal "dump-456", response[:id]
    assert_equal "Pending…", response[:status]
  end

  test "request_dump reuses an unexpired completed wakatime export" do
    client = HeartbeatImportDumpClient.new(source_kind: :wakatime_dump, api_key: "waka_tok_abc")

    stub_request(:post, "https://wakatime.com/api/v1/users/current/data_dumps")
      .to_return(status: 400, body: { error: "Wait for your current export to expire before creating another." }.to_json)
    stub_request(:get, "https://wakatime.com/api/v1/users/current/data_dumps")
      .to_return(status: 200, body: {
        data: [
          { id: "daily", type: "daily", download_url: "https://wakatime.s3.amazonaws.com/daily.json", created_at: "2026-11-19T00:00:00Z" },
          { id: "older", type: "heartbeats", download_url: "https://wakatime.s3.amazonaws.com/older.json", created_at: "2026-11-10T00:00:00Z" },
          { id: "latest", type: "heartbeats", download_url: "https://wakatime.s3.amazonaws.com/latest.json", created_at: "2026-11-18T00:00:00Z" }
        ]
      }.to_json)

    response = client.request_dump

    assert_equal "latest", response[:id]
    assert_equal "2026-11-18T00:00:00Z", response[:created_at]
  end

  test "list_user_agents and list_machine_names read every page" do
    client = HeartbeatImportDumpClient.new(source_kind: :wakatime_dump, api_key: "waka_tok_abc")

    { "user_agents" => %w[ua-1 ua-2], "machine_names" => %w[m-1 m-2] }.each do |resource, (first, second)|
      stub_request(:get, "https://wakatime.com/api/v1/users/current/#{resource}?page=1")
        .to_return(status: 200, body: { data: [ { id: first, value: "#{first}-value" } ], total_pages: 2 }.to_json)
      stub_request(:get, "https://wakatime.com/api/v1/users/current/#{resource}?page=2")
        .to_return(status: 200, body: { data: [ { id: second, value: "#{second}-value" } ], total_pages: 2 }.to_json)
    end

    assert_equal %w[ua-1 ua-2], client.list_user_agents.map { _1[:id] }
    assert_equal [ { id: "m-1", value: "m-1-value" }, { id: "m-2", value: "m-2-value" } ], client.list_machine_names
  end

  test "download_dump reuses auth header for same-host downloads" do
    client = HeartbeatImportDumpClient.new(source_kind: :hackatime_v1_dump, api_key: "secret-key")

    stub = stub_request(:get, "https://waka.hackclub.com/downloads/dump-123.json")
      .with(
        headers: {
          "Authorization" => "Basic #{Base64.strict_encode64("secret-key")}",
          "Accept" => "application/json,application/octet-stream,*/*"
        }
      )
      .to_return(status: 200, body: '{"heartbeats":[]}')

    body = client.download_dump("https://waka.hackclub.com/downloads/dump-123.json")

    assert_requested stub
    assert_equal '{"heartbeats":[]}', body
  end

  test "request_dump raises manual download link required for wakatime 400 responses" do
    client = HeartbeatImportDumpClient.new(source_kind: :wakatime_dump, api_key: "secret-key")

    stub_request(:post, "https://wakatime.com/api/v1/users/current/data_dumps")
      .to_return(status: 400, body: { error: "too soon" }.to_json, headers: { "Content-Type" => "application/json" })

    assert_raises(HeartbeatImportDumpClient::ManualDownloadLinkRequiredError) do
      client.request_dump
    end
  end

  test "request_dump preserves 401 status on authentication errors" do
    client = HeartbeatImportDumpClient.new(source_kind: :wakatime_dump, api_key: "secret-key")

    stub_request(:post, "https://wakatime.com/api/v1/users/current/data_dumps")
      .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: { "Content-Type" => "application/json" })

    error = assert_raises(HeartbeatImportDumpClient::AuthenticationError) do
      client.request_dump
    end

    assert_equal 401, error.status
  end

  test "request_dump preserves 500 status on provider errors" do
    client = HeartbeatImportDumpClient.new(source_kind: :hackatime_v1_dump, api_key: "secret-key")

    stub_request(:post, "https://waka.hackclub.com/api/v1/users/current/data_dumps")
      .to_return(status: 500, body: { error: "Internal Server Error" }.to_json, headers: { "Content-Type" => "application/json" })

    error = assert_raises(HeartbeatImportDumpClient::TransientError) do
      client.request_dump
    end

    assert_equal 500, error.status
  end
end
