require "test_helper"
require "webmock/minitest"

class SailorsLogLeaderboardTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "opting out excludes activity and expires reusable messages while rejoining restores activity" do
    travel_to Time.current.middle_of_day
    user = create(:user, slack_uid: "U_LEADERBOARD_OPT_OUT")
    participant = create(:user, slack_uid: "U_LEADERBOARD_VISIBLE")
    channel = "C_LEADERBOARD_OPT_OUT"
    [ user, participant ].each do |coder|
      SailorsLogNotificationPreference.create!(slack_uid: coder.slack_uid, slack_channel_id: channel, enabled: true)
      [ 2.minutes.ago, 1.minute.ago ].each do |time|
        create(:heartbeat, user: coder, time: time.to_f, project: "leaderboard-test")
      end
    end
    message = SailorsLogLeaderboard.create!(slack_uid: user.slack_uid, slack_channel_id: channel)
    assert_includes message.message, user.slack_uid
    assert_includes SailorsLogLeaderboard.reusable, message

    user.update!(leaderboard_opt_out: true)

    assert_not_includes SailorsLogLeaderboard.reusable, message
    stats = SailorsLogLeaderboard.generate_leaderboard_stats(channel)
    assert_equal [ participant.slack_uid ], stats.pluck(:slack_uid)
    assert_equal 60, stats.first[:duration]

    user.update!(leaderboard_opt_out: false)
    assert_equal [ user.slack_uid, participant.slack_uid ].sort,
      SailorsLogLeaderboard.generate_leaderboard_stats(channel).pluck(:slack_uid).sort
  end
end

class SailorsLogLeaderboardConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "a message committed after opt out is not reused by the Slack command" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    travel_to Time.current.middle_of_day
    channel = "C_CONCURRENT_OPT_OUT"
    user = create(:user, slack_uid: "U_CONCURRENT_OPT_OUT")
    SailorsLogNotificationPreference.create!(slack_uid: user.slack_uid, slack_channel_id: channel, enabled: true)
    [ 2.minutes.ago, 1.minute.ago ].each do |time|
      create(:heartbeat, user: user, time: time.to_f)
    end
    generated = Queue.new
    release_commit = Queue.new

    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        SailorsLogLeaderboard.transaction do
          board = SailorsLogLeaderboard.create!(slack_uid: user.slack_uid, slack_channel_id: channel)
          generated << board
          release_commit.pop
          board
        end
      end
    end

    board = Timeout.timeout(10) { generated.pop }
    assert_includes board.message, user.slack_uid
    assert_not SailorsLogLeaderboard.exists?(board.id), "the message must still be uncommitted"
    user.update!(leaderboard_opt_out: true)
    release_commit << true
    Timeout.timeout(10) { worker.value }
    assert_nil board.reload.deleted_at

    messages = []
    response_url = "https://example.com/slack/leaderboard-response"
    stub_request(:post, response_url).to_return do |request|
      messages << JSON.parse(request.body).fetch("text")
      { body: "ok" }
    end

    SlackCommand::SailorsLogLeaderboardJob.perform_now(user.slack_uid, channel, response_url)

    assert_equal "No coding activity found for today. :3kskull:", messages.last
    assert_not_includes messages.last, user.slack_uid
  ensure
    release_commit << true if release_commit
    worker&.join(10)
    SailorsLogLeaderboard.where(slack_channel_id: channel).delete_all
    SailorsLogNotificationPreference.where(slack_channel_id: channel).delete_all
    if user
      Heartbeat.with_excluded.where(user_id: user.id).delete_all
      user.destroy!
      SailorsLog.where(slack_uid: user.slack_uid).delete_all
    end
    Rails.cache = original_cache
  end
end
