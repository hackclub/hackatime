class Api::V1::LeaderboardController < ApplicationController
  before_action :ensure_authenticated!

  def daily
    leaderboard = LeaderboardService.get(period: :daily, date: Date.current)

    if leaderboard.nil?
      render json: { error: "Leaderboard is being generated" }, status: :service_unavailable
    else
      render json: format_leaderboard(leaderboard)
    end
  end

  def weekly
    leaderboard = LeaderboardService.get(period: :last_7_days, date: Date.current)

    if leaderboard.nil?
      render json: { error: "Leaderboard is being generated" }, status: :service_unavailable
    else
      render json: format_leaderboard(leaderboard)
    end
  end

  private

  def format_leaderboard(leaderboard)
    entries = leaderboard.entries.includes(:user).order(total_seconds: :desc).map do |entry|
      {
        rank: nil,
        user: {
          id: entry.user.id,
          username: entry.user.display_name,
          avatar_url: entry.user.avatar_url
        },
        total_seconds: entry.total_seconds
      }
    end

    entries.each_with_index { |entry, idx| entry[:rank] = idx + 1 }

    {
      period: leaderboard.period_type,
      start_date: leaderboard.start_date.iso8601,
      date_range: leaderboard.date_range_text,
      generated_at: leaderboard.finished_generating_at&.iso8601,
      entries: entries
    }
  end

  def ensure_authenticated!
    return if Rails.env.development?

    token = request.headers["Authorization"]&.split(" ")&.last
    token ||= params[:api_key]

    unless token == ENV["STATS_API_KEY"]
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
