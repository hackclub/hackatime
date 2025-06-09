class LeaderboardsController < ApplicationController
  def index
    @period_type = (params[:period_type] || "daily").to_sym
    @period_type = :daily unless Leaderboard.period_types
                                            .keys
                                            .map(&:to_sym)
                                            .include?(@period_type)

    start_date = case @period_type
    when :weekly
      Date.current.beginning_of_week
    when :last_7_days
      Date.current
    else
      Date.current
    end

    cache_key = "leaderboard_#{@period_type}_#{start_date}"
    @leaderboard = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      Leaderboard.where.not(finished_generating_at: nil)
                 .find_by(
                   start_date: start_date,
                   period_type: @period_type,
                   deleted_at: nil
                 )
      end
    Rails.cache.delete(cache_key) if @leaderboard.nil?

    if @leaderboard.nil?
      LeaderboardUpdateJob.perform_later @period_type
      flash.now[:notice] = "Leaderboard is being updated..."
    else
      # Load entries with users and their project repo mappings in a single query
      @entries = @leaderboard.entries
                             .includes(:user)
                             .order(total_seconds: :desc)

      tracked_user_ids = @leaderboard.entries.distinct.pluck(:user_id)

      @user_on_leaderboard = current_user && tracked_user_ids.include?(current_user.id)
      unless @user_on_leaderboard
        time_range = case @period_type
        when :weekly
          (start_date.beginning_of_day...(start_date + 7.days).beginning_of_day)
        when :last_7_days
          ((start_date - 6.days).beginning_of_day...start_date.end_of_day)
        else
          start_date.all_day
        end

        @untracked_entries = Hackatime::Heartbeat
            .where(time: time_range)
            .distinct
            .pluck(:user_id)
            .count { |user_id| !tracked_user_ids.include?(user_id) }
      end

      @active_projects = Cache::ActiveProjectsJob.perform_now
    end
  end
end
