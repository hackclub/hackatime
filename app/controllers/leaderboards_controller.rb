class LeaderboardsController < ApplicationController
  def index
    @period_type = (params[:period_type] || "daily").to_sym
    @period_type = :daily unless [ :daily, :weekly ].include?(@period_type)

    start_date = if @period_type == :weekly
      Date.current.beginning_of_week
    else
      Date.current
    end

    @leaderboard = Leaderboard.find_by(
      start_date: start_date,
      period_type: @period_type,
      deleted_at: nil
    )

    if @leaderboard.nil?
      LeaderboardUpdateJob.perform_later(start_date, @period_type)
      flash.now[:notice] = "Leaderboard is being updated..."
    else
      @entries = @leaderboard.entries
                             .includes(:user)
                             .order(total_seconds: :desc)

      tracked_user_ids = @leaderboard.entries.distinct.pluck(:user_id)

      @user_on_leaderboard = current_user && tracked_user_ids.include?(current_user.id)
      unless @user_on_leaderboard
        time_range = if @period_type == :weekly
                      (start_date.beginning_of_day...(start_date + 7.days).beginning_of_day)
        else
          Time.current
        end

        @untracked_entries = Hackatime::Heartbeat
            .where(time: time_range)
            .distinct
            .pluck(:user_id)
            .count { |user_id| !tracked_user_ids.include?(user_id) }
      end
    end
  end
end
