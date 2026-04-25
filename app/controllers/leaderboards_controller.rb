class LeaderboardsController < InertiaController
  layout "inertia"

  def index
    period_type = validated_period_type
    country = load_country_context
    leaderboard_scope = validated_leaderboard_scope(country)

    leaderboard = LeaderboardService.get(period: period_type, date: Date.current)

    render inertia: "Leaderboards/Index", props: {
      period_type: period_type.to_s,
      scope: leaderboard_scope.to_s,
      country: country,
      leaderboard: leaderboard_metadata(leaderboard),
      is_logged_in: current_user.present?,
      github_uid_blank: current_user&.github_uid.blank? || false,
      github_auth_path: "/auth/github",
      settings_path: my_settings_path,
      entries: entries_payload(leaderboard, leaderboard_scope, country)
    }
  end

  private

  def validated_period_type
    p = (params[:period_type] || "daily").to_s
    %w[daily last_7_days].include?(p) ? p.to_sym : :daily
  end

  def validated_leaderboard_scope(country)
    requested = params[:scope].to_s
    requested = "global" unless %w[global country].include?(requested)
    requested = "global" if requested == "country" && !country[:available]
    requested.to_sym
  end

  def load_country_context
    c = ISO3166::Country.new(current_user&.country_code)
    {
      code: c&.alpha2,
      name: c&.common_name,
      available: c&.alpha2.present? && c&.common_name.present?
    }
  end

  def leaderboard_metadata(leaderboard)
    return nil unless leaderboard&.persisted?

    {
      date_range_text: leaderboard.date_range_text,
      updated_at: leaderboard.updated_at&.iso8601,
      finished_generating: leaderboard.finished_generating?,
      generation_duration_seconds: leaderboard.generation_duration_seconds
    }
  end

  def entries_payload(leaderboard, scope, country)
    return { entries: [], total: 0 } unless leaderboard&.persisted?

    country_code = (scope == :country && country[:available]) ? country[:code] : nil
    payload = LeaderboardPageCache.fetch(
      leaderboard: leaderboard,
      scope: scope,
      country_code: country_code
    )

    active_projects = Cache::ActiveProjectsJob.perform_now

    entries = payload[:entries].map do |e|
      user = e[:user]
      proj = active_projects&.dig(e[:user_id])
      {
        user_id: e[:user_id],
        total_seconds: e[:total_seconds],
        streak_count: e[:streak_count],
        is_current_user: e[:user_id] == current_user&.id,
        user: {
          display_name: user[:display_name],
          avatar_url: user[:avatar_url],
          profile_path: user[:profile_path],
          verified: user[:verified],
          country_code: user[:country_code],
          red: user[:red]
        },
        active_project: proj ? { name: proj.project_name, repo_url: proj.repo_url } : nil
      }
    end

    {
      entries: entries,
      total: payload[:total_entries]
    }
  end
end
