require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

class UserSlackStatusUpdateJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "updates only the requested user" do
    user = create(:user, slack_access_token: "requested-token", uses_slack_status: true)
    create(:user, slack_access_token: "other-token", uses_slack_status: true)
    request = stub_request(:get, "https://slack.com/api/users.profile.get")
      .with(headers: { "Authorization" => "Bearer requested-token" })
      .to_return(body: { profile: { status_text: "In a meeting" } }.to_json)

    UserSlackStatusUpdateJob.perform_now(user.id)

    assert_requested request, times: 1
  end

  test "retries a transient Slack connection failure" do
    user = create(:user, slack_access_token: "requested-token", uses_slack_status: true)
    request = stub_request(:get, "https://slack.com/api/users.profile.get")
      .to_raise(HTTP::ConnectionError.new("Slack unavailable"))
      .then
      .to_return(body: { profile: { status_text: "In a meeting" } }.to_json)

    assert_enqueued_with(job: UserSlackStatusUpdateJob, args: [ user.id ]) do
      UserSlackStatusUpdateJob.perform_now(user.id)
    end

    perform_enqueued_jobs(only: UserSlackStatusUpdateJob)

    assert_requested request, times: 2
  end

  test "does nothing when the user no longer exists" do
    missing_user_id = User.maximum(:id).to_i + 1

    UserSlackStatusUpdateJob.perform_now(missing_user_id)

    assert_not_requested :any, %r{\Ahttps://slack\.com/}
  end
end
