require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

class SailorsLogPollForChangesJobTest < ActiveSupport::TestCase
  setup do
    @original_slack_token = ENV["SAILORS_LOG_SLACK_BOT_OAUTH_TOKEN"]
    ENV["SAILORS_LOG_SLACK_BOT_OAUTH_TOKEN"] = "test-token"
  end

  teardown do
    ENV["SAILORS_LOG_SLACK_BOT_OAUTH_TOKEN"] = @original_slack_token
  end

  test "notifies for a recently received direct heartbeat with an old coding timestamp" do
    user = create(:user, slack_uid: "U_DELAYED_DIRECT")
    sailors_log = create(:sailors_log, user: user, slack_uid: user.slack_uid, projects_summary: { "nixos" => 3_500 })
    create(:heartbeat,
      user:, time: 3.weeks.ago.to_f, project: "nixos", category: "coding",
      entity: "/tmp/configuration.nix", type: "file", source_type: :direct_entry
    )
    create(:dashboard_rollup,
      user_id: user.id, dimension: "project", bucket_value: "nixos",
      bucket_value_present: true, total_seconds: 22_209
    )
    stub_request(:get, "https://slack.com/api/users.info?user=#{user.slack_uid}")
      .to_return(status: 200, body: { ok: true, user: { profile: { display_name: "Sailor" } } }.to_json)
    slack_request = stub_request(:post, "https://slack.com/api/chat.postMessage")
      .with { |request| JSON.parse(request.body).fetch("text").include?("has now coded for *6 hours* on *nixos*") }
      .to_return(status: 200, body: { ok: true }.to_json)

    assert_difference -> { sailors_log.notifications.count }, +1 do
      SailorsLogPollForChangesJob.perform_now
    end

    notification = sailors_log.notifications.last
    assert notification.sent?
    assert_equal "nixos", notification.project_name
    assert_equal 22_209, notification.project_duration
    assert_requested slack_request
  end

  test "does not notify for a recently imported heartbeat with an old coding timestamp" do
    user = create(:user, slack_uid: "U_DELAYED_IMPORT")
    sailors_log = create(:sailors_log, user: user, slack_uid: user.slack_uid, projects_summary: { "imported" => 3_500 })
    create(:heartbeat,
      user:, time: 3.weeks.ago.to_f, project: "imported", category: "coding",
      entity: "/tmp/imported.rb", type: "file", source_type: :wakapi_import
    )
    create(:dashboard_rollup,
      user_id: user.id, dimension: "project", bucket_value: "imported",
      bucket_value_present: true, total_seconds: 3_700
    )

    assert_no_difference -> { sailors_log.notifications.count } do
      SailorsLogPollForChangesJob.perform_now
    end
    assert_equal 3_500, sailors_log.reload.projects_summary.fetch("imported")
  end

  test "does not notify while any heartbeat import is active" do
    user = create(:user, slack_uid: "U_ACTIVE_IMPORT")
    sailors_log = create(:sailors_log, user: user, slack_uid: user.slack_uid, projects_summary: { "imported" => 3_500 })
    create(:heartbeat_import_run, user: user, source_kind: :dev_upload, state: :importing)
    create(:heartbeat,
      user:, time: Time.current.to_f, project: "imported", category: "coding",
      entity: "/tmp/imported.rb", type: "file", source_type: :wakapi_import
    )
    create(:dashboard_rollup,
      user_id: user.id, dimension: "project", bucket_value: "imported",
      bucket_value_present: true, total_seconds: 3_700
    )

    assert_no_difference -> { sailors_log.notifications.count } do
      SailorsLogPollForChangesJob.perform_now
    end
    assert_equal 3_500, sailors_log.reload.projects_summary.fetch("imported")
  end
end
