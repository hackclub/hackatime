require "test_helper"

class LeaderboardShadowbanExpirationJobTest < ActiveJob::TestCase
  test "removes an expired leaderboard shadowban" do
    actor = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "expired_shadowban_job")
    expires_at = 1.hour.from_now
    user.set_leaderboard_shadowban(
      banned: true,
      changed_by_user: actor,
      reason: "temporary fake time",
      expires_at: expires_at
    )

    travel_to(expires_at + 1.second) do
      LeaderboardShadowbanExpirationJob.perform_now(user.id)
    end

    assert_not user.reload.leaderboard_shadowbanned?
    assert_nil user.leaderboard_shadowban_reason
    assert_nil user.leaderboard_shadowbanned_by
    assert_nil user.leaderboard_shadowban_expires_at
  end

  test "ignores stale expiration jobs for a later shadowban expiration" do
    actor = User.create!(timezone: "UTC", admin_level: :superadmin)
    user = User.create!(timezone: "UTC", username: "stale_shadowban_job")
    later_expires_at = 2.days.from_now
    user.set_leaderboard_shadowban(
      banned: true,
      changed_by_user: actor,
      reason: "temporary fake time",
      expires_at: later_expires_at
    )

    LeaderboardShadowbanExpirationJob.perform_now(user.id)

    assert user.reload.leaderboard_shadowbanned?
    assert_equal later_expires_at.to_i, user.leaderboard_shadowban_expires_at.to_i
  end

  test "ignores already removed shadowbans" do
    user = User.create!(timezone: "UTC", username: "removed_shadowban_job")

    assert_nothing_raised do
      LeaderboardShadowbanExpirationJob.perform_now(user.id)
    end

    assert_not user.reload.leaderboard_shadowbanned?
  end
end
