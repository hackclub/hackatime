class LeaderboardPageCache
  CACHE_EXPIRATION = 10.minutes

  class << self
    def fetch(leaderboard:, scope:, country_code: nil)
      Rails.cache.fetch(cache_key(leaderboard, scope, country_code), expires_in: CACHE_EXPIRATION) do
        build_payload(leaderboard: leaderboard, scope: scope, country_code: country_code)
      end
    end

    def warm(leaderboard:)
      fetch(leaderboard: leaderboard, scope: :global)
    end

    private

    def cache_key(leaderboard, scope, country_code)
      scope_suffix = scope.to_sym == :country ? (country_code.presence || "none") : "global"
      "leaderboard_page/#{leaderboard.cache_key_with_version}/#{scope}/#{scope_suffix}"
    end

    def build_payload(leaderboard:, scope:, country_code:)
      rows = entries_scope(
        leaderboard: leaderboard,
        scope: scope,
        country_code: country_code
      ).map do |entry|
        {
          user_id: entry.user_id,
          total_seconds: entry.total_seconds,
          streak_count: entry.streak_count,
          user: serialize_user(entry.user)
        }
      end

      {
        total_entries: rows.size,
        user_ids: rows.map { |row| row[:user_id] },
        entries: rows
      }
    end

    def entries_scope(leaderboard:, scope:, country_code:)
      scope_query = leaderboard.entries.order(total_seconds: :desc)
      if scope.to_sym == :country && country_code.present?
        scope_query = scope_query.joins(:user).where(users: { country_code: country_code })
      end

      scope_query.preload(:user)
    end

    def serialize_user(user)
      {
        id: user.id,
        display_name: user.display_name,
        avatar_url: user.avatar_url,
        profile_path: user.username.present? ? routes.profile_path(user.username) : nil,
        verified: user.trust_level == "green",
        red: user.red?,
        country_code: user.country_code
      }
    end

    def routes
      Rails.application.routes.url_helpers
    end
  end
end
