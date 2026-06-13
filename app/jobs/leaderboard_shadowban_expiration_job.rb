class LeaderboardShadowbanExpirationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user&.leaderboard_shadowbanned?
    return if user.leaderboard_shadowban_expires_at.blank?
    return if user.leaderboard_shadowban_expires_at.future?

    user.update!(
      leaderboard_shadowbanned: false,
      leaderboard_shadowban_reason: nil,
      leaderboard_shadowbanned_by: nil,
      leaderboard_shadowban_expires_at: nil
    )
  end
end
