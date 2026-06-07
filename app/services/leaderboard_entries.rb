class LeaderboardEntries
  CACHE_EXPIRATION = 10.minutes

  def self.fetch(...) = new(...).fetch
  def self.fetch_public(leaderboard:) = new(leaderboard:).fetch_public
  def self.warm_public(leaderboard:) = fetch_public(leaderboard:)

  def initialize(leaderboard:, viewer: nil, scope: :global, country_code: nil, include_active_projects: false)
    @leaderboard = leaderboard
    @viewer = viewer
    @scope = scope.to_sym
    @country_code = country_code
    @include_active_projects = include_active_projects
  end

  def fetch
    return { entries: [], total: 0 } unless @leaderboard&.persisted?

    active_projects = @include_active_projects ? Cache::ActiveProjectsJob.perform_now : nil
    entries = visible_cached_entries.map.with_index(1) do |entry, rank|
      entry_payload(entry, rank:, active_projects:)
    end

    { entries:, total: entries.size }
  end

  def fetch_public
    return { entries: [], total: 0 } unless @leaderboard&.persisted?

    entries = Rails.cache.fetch(public_cache_key, expires_in: CACHE_EXPIRATION) do
      public_entries_from_database
    end

    { entries:, total: entries.size }
  end

  private

  def public_cache_key
    "leaderboard_entries/public/v1/#{LeaderboardPageCache.version}/#{@leaderboard.cache_key_with_version}"
  end

  def public_entries_from_database
    @leaderboard.entries
      .joins(:user)
      .where(users: { leaderboard_shadowbanned: false })
      .preload(:user)
      .order(total_seconds: :desc, user_id: :asc)
      .map.with_index(1) do |row, rank|
        public_entry_payload(row, rank:)
      end
  end

  def public_entry_payload(entry, rank:)
    {
      rank:,
      user_id: entry.user_id,
      total_seconds: entry.total_seconds,
      streak_count: entry.streak_count,
      is_current_user: false,
      user: {
        id: entry.user.id,
        display_name: entry.user.display_name,
        avatar_url: entry.user.avatar_url
      },
      active_project: nil
    }
  end

  def visible_cached_entries
    cached_entries.reject { |entry| entry_hidden_from_viewer?(entry) }
  end

  def cached_entries
    LeaderboardPageCache.fetch(
      leaderboard: @leaderboard,
      scope: @scope,
      country_code: @country_code
    )[:entries]
  end

  def entry_hidden_from_viewer?(entry)
    entry.dig(:user, :shadowbanned) && entry[:user_id] != @viewer&.id
  end

  def entry_payload(entry, rank:, active_projects:)
    user = entry[:user]
    {
      rank:,
      user_id: entry[:user_id],
      total_seconds: entry[:total_seconds],
      streak_count: entry[:streak_count],
      is_current_user: entry[:user_id] == @viewer&.id,
      user: user_payload(user),
      active_project: active_project_payload(active_projects&.dig(entry[:user_id]))
    }
  end

  def user_payload(user)
    {
      id: user[:id],
      display_name: user[:display_name],
      avatar_url: user[:avatar_url],
      profile_path: user[:profile_path],
      verified: user[:verified],
      country_code: user[:country_code],
      red: user[:red]
    }
  end

  def active_project_payload(active_project)
    return nil unless active_project

    { name: active_project.project_name, repo_url: active_project.repo_url }
  end
end
