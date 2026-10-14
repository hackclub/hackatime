require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

class SettingsSlackGithubControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "update enables Slack status and enqueues the user without contacting Slack" do
    user = create(:user, slack_access_token: "slack-token", uses_slack_status: false)
    sign_in_as(user)

    assert_enqueued_with(job: UserSlackStatusUpdateJob, args: [ user.id ]) do
      patch my_settings_slack_github_update_path, params: { user: { uses_slack_status: "1" } }
    end

    assert_response :redirect
    assert_redirected_to my_settings_slack_github_path
    assert user.reload.uses_slack_status?
    assert_not_requested :any, %r{\Ahttps://slack\.com/}
  end

  test "update does not enqueue Slack status work when the preference update fails" do
    user = create(:user, uses_slack_status: false)
    user.update_column(:country_code, "not-a-country")
    sign_in_as(user)

    assert_no_enqueued_jobs only: UserSlackStatusUpdateJob do
      patch my_settings_slack_github_update_path, params: { user: { uses_slack_status: "1" } }
    end

    assert_response :unprocessable_entity
    assert_not user.reload.uses_slack_status?
  end
end
