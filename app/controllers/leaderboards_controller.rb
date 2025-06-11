class LeaderboardsController < ApplicationController
  def index
    # Check if current user wants timezone-normalized view
    @use_timezone_leaderboard = current_user && Flipper.enabled?(:timezone_leaderboard, current_user)

    @period_type = (params[:period_type] || "daily").to_sym

    # Default to regional scope for timezone leaderboard users, global for others
    @scope = params[:scope] || (@use_timezone_leaderboard ? "regional" : "global")

    # Handle regional/timezone-specific leaderboards
    if @scope == "regional" || @scope == "timezone"
      handle_regional_leaderboard
      return
    end

    # For global scope, continue with normal leaderboard logic
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
      # Use appropriate job for timezone vs regular leaderboards
      if @period_type == :daily_timezone_normalized
        TimezoneLeaderboardUpdateJob.perform_later(start_date)
      else
        LeaderboardUpdateJob.perform_later @period_type
      end
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

  private

  def handle_regional_leaderboard
    # Determine date range based on period type
    start_date = case @period_type
    when :weekly
                   Date.current.beginning_of_week
    when :last_7_days
                   Date.current - 6.days
    else
                   Date.current
    end

    # Require user to be logged in and have timezone set
    unless current_user&.timezone
      flash[:error] = "Please set your timezone in settings to view regional leaderboards"
      redirect_to my_settings_path
      return
    end

    if @scope == "regional"
      # Regional leaderboard based on current user's UTC offset
      user_utc_offset = current_user.timezone_utc_offset

      if user_utc_offset.nil?
        flash[:error] = "Unable to determine UTC offset for your timezone: #{current_user.timezone}"
        redirect_to leaderboards_path
        return
      end

      @leaderboard = LeaderboardGenerator.generate_timezone_offset_leaderboard(start_date, user_utc_offset, @period_type)
      @scope_description = current_user.timezone_offset_name
    elsif @scope == "timezone"
      # Timezone-specific leaderboard for current user's timezone
      @leaderboard = LeaderboardGenerator.generate_timezone_leaderboard(start_date, current_user.timezone, @period_type)
      @scope_description = current_user.timezone
    end

    # Set up common variables
    if @leaderboard
      @entries = @leaderboard.entries
      @user_on_leaderboard = current_user && @entries.any? { |entry| entry.user_id == current_user.id }
      @untracked_entries = 0 # Skip this for regional leaderboards for now
      @active_projects = Cache::ActiveProjectsJob.perform_now
    end
  end
end
