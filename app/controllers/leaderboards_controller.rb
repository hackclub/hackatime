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
      github_uid_blank: current_user.present? && current_user.github_uid.blank?,
      entries: InertiaRails.defer { entries_payload(leaderboard, leaderboard_scope, country) }
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
    code = current_user&.country_code.presence || country_code_from_request_ip
    c = ISO3166::Country.new(code)
    {
      code: c&.alpha2,
      name: c&.common_name,
      available: c&.alpha2.present? && c&.common_name.present?
    }
  end

  def country_code_from_request_ip
    ip = request.remote_ip
    return nil if ip.blank?

    Rails.cache.fetch([ "leaderboards", "ip_country", ip ], expires_in: 1.day) do
      User.country_code_from_ip(ip)
    end
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
    country_code = (scope == :country && country[:available]) ? country[:code] : nil
    LeaderboardEntries.fetch(
      leaderboard: leaderboard,
      scope: scope,
      country_code: country_code,
      viewer: current_user,
      include_active_projects: true
    )
  end
end
