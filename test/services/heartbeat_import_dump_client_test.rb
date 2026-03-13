require "test_helper"
require "webmock/minitest"

class HeartbeatImportDumpClientTest < ActiveSupport::TestCase
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
end
