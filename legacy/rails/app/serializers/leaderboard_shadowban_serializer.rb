# frozen_string_literal: true

# serializes a User for the leaderboard-shadowban admin UI (Inertia) and API.
# timestamps are emitted as ISO8601 and formatted for display on the client.
class LeaderboardShadowbanSerializer
  # associations this serializer reads. eager-load these to avoid N+1.
  PRELOADS = [ :email_addresses, :leaderboard_shadowbanned_by ].freeze

  def self.call(user) = new(user).as_json

  def initialize(user)
    @user = user
  end

  def as_json
    {
      id: user.id,
      display_name: user.display_name,
      avatar_url: user.avatar_url,
      created_at: user.created_at&.iso8601,
      username: user.username,
      email: user.email_addresses.first&.email,
      leaderboard_shadowbanned: user.leaderboard_shadowbanned?,
      leaderboard_shadowban_reason: user.leaderboard_shadowban_reason,
      leaderboard_shadowban_expires_at: user.leaderboard_shadowban_expires_at&.iso8601,
      shadowbanned_by: shadowbanned_by_json,
      updated_at: user.updated_at&.iso8601
    }
  end

  private

  attr_reader :user

  def shadowbanned_by_json
    admin = user.leaderboard_shadowbanned_by
    return nil unless admin

    {
      id: admin.id,
      display_name: admin.display_name,
      username: admin.username,
      avatar_url: admin.avatar_url,
      admin_level: admin.admin_level
    }
  end
end
