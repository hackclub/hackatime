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
    entries = LeaderboardEntries.fetch_public(leaderboard: leaderboard)[:entries].map do |entry|
      { rank: entry[:rank],
        user: { id: entry[:user_id], username: entry.dig(:user, :display_name), avatar_url: entry.dig(:user, :avatar_url) },
        total_seconds: entry[:total_seconds] }
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
