class Api::V1::LeaderboardController < ApplicationController
  def daily = render_period(:daily)
  def weekly = render_period(:last_7_days)

  private

  def render_period(period)
    leaderboard = LeaderboardService.get(period: period, date: Date.current)
    if leaderboard.nil?
      render json: { error: "Leaderboard is being generated" }, status: :service_unavailable
    else
      render json: format_leaderboard(leaderboard)
    end
  end

  def format_leaderboard(leaderboard)
    entries = leaderboard.entries
      .joins(:user)
      .where(users: { leaderboard_shadowbanned: false })
      .preload(:user)
      .order(total_seconds: :desc)
      .map.with_index do |entry, idx|
      { rank: idx + 1,
        user: { id: entry.user.id, username: entry.user.display_name, avatar_url: entry.user.avatar_url },
        total_seconds: entry.total_seconds }
    end

    {
      period: leaderboard.period_type,
      start_date: leaderboard.start_date.iso8601,
      date_range: leaderboard.date_range_text,
      generated_at: leaderboard.finished_generating_at&.iso8601,
      entries: entries
    }
  end
end
