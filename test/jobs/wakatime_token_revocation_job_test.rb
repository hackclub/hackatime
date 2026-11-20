require "test_helper"
require "webmock/minitest"

class WakatimeTokenRevocationJobTest < ActiveJob::TestCase
  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    @original_env = ENV.to_h.slice("WAKATIME_CLIENT_ID", "WAKATIME_CLIENT_SECRET")
    ENV.update("WAKATIME_CLIENT_ID" => "test-client", "WAKATIME_CLIENT_SECRET" => "test-secret")
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    ENV.delete("WAKATIME_CLIENT_ID")
    ENV.delete("WAKATIME_CLIENT_SECRET")
    ENV.update(@original_env)
  end

  test "retries until wakatime revokes the token" do
    revoke = stub_request(:post, "https://wakatime.com/oauth/revoke")
      .with(body: { client_id: "test-client", client_secret: "test-secret", token: "waka_tok_live" })
      .to_return({ status: 503 }, { status: 200 })

    WakatimeTokenRevocationJob.revoke_later("waka_tok_live")
    assert_enqueued_jobs 1, only: WakatimeTokenRevocationJob

    perform_enqueued_jobs(only: WakatimeTokenRevocationJob)
    assert_requested revoke, times: 1
    assert_enqueued_jobs 1, only: WakatimeTokenRevocationJob

    perform_enqueued_jobs(only: WakatimeTokenRevocationJob)
    assert_requested revoke, times: 2
    assert_no_enqueued_jobs only: WakatimeTokenRevocationJob
  end
end
