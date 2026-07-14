require "test_helper"

class SailorsLogPollForChangesJobTest < ActiveJob::TestCase
  test "loads all selected users project durations in one serving query" do
    user = User.create!(slack_uid: "UPOLL#{SecureRandom.hex(4)}", timezone: "UTC")
    base = 2.minutes.ago
    create_heartbeat(user:, time: base.to_f, project: "alpha", category: "coding", source_type: :direct_entry)
    create_heartbeat(user:, time: (base + 60.seconds).to_f, project: "alpha", category: "coding", source_type: :direct_entry)
    SailorsLog.create!(slack_uid: user.slack_uid)

    serving_queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.clickhouse_serving") do |*, payload|
      serving_queries << payload.fetch(:sql)
    end

    SailorsLogPollForChangesJob.perform_now

    assert_equal 1, serving_queries.size
    assert_match(/FROM heartbeat_project_summaries/, serving_queries.first)
    assert_empty SailorsLogSlackNotification.where(slack_uid: user.slack_uid)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
