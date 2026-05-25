class LeaderboardPageCache
  CACHE_EXPIRATION = 10.minutes

  class << self
    def fetch(leaderboard:, scope:, country_code: nil)
      Rails.cache.fetch(cache_key(leaderboard, scope, country_code), expires_in: CACHE_EXPIRATION) do
        build_payload(leaderboard:, scope:, country_code:)
      end
    end

    def warm(leaderboard:) = fetch(leaderboard:, scope: :global)

    private

    def cache_key(leaderboard, scope, country_code)
      scope_suffix = scope.to_sym == :country ? (country_code.presence || "none") : "global"
      "leaderboard_page/v2/#{leaderboard.cache_key_with_version}/#{scope}/#{scope_suffix}"
    end

    def build_payload(leaderboard:, scope:, country_code:)
      rows = entries_scope(leaderboard:, scope:, country_code:).map do |entry|
        { user_id: entry.user_id, total_seconds: entry.total_seconds,
          streak_count: entry.streak_count, user: serialize_user(entry.user) }
      end
      { total_entries: rows.size, user_ids: rows.map { |r| r[:user_id] }, entries: rows }
    end

    def entries_scope(leaderboard:, scope:, country_code:)
      q = leaderboard.entries.order(total_seconds: :desc)
      q = q.joins(:user).where(users: { country_code: }) if scope.to_sym == :country && country_code.present?
      q.preload(user: :email_addresses)
    end

    def serialize_user(user)
      {
        id: user.id, display_name: user.display_name, avatar_url: user.avatar_url,
        profile_path: user.username.present? ? Rails.application.routes.url_helpers.profile_path(user.username) : nil,
        verified: user.trust_level == "green", red: user.red?,
        shadowbanned: user.leaderboard_shadowbanned?, country_code: user.country_code
      }
    end
  end
end
