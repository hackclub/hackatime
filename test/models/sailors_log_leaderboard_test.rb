require "test_helper"

class SailorsLogLeaderboardTest < ActiveSupport::TestCase
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

    user.update!(leaderboard_opt_out: true)

    assert_not_nil message.reload.deleted_at
    stats = SailorsLogLeaderboard.generate_leaderboard_stats(channel)
    assert_equal [ participant.slack_uid ], stats.pluck(:slack_uid)
    assert_equal 60, stats.first[:duration]

    user.update!(leaderboard_opt_out: false)
    assert_equal [ user.slack_uid, participant.slack_uid ].sort,
      SailorsLogLeaderboard.generate_leaderboard_stats(channel).pluck(:slack_uid).sort
  end
end
