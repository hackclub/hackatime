class LeaderboardsController < ApplicationController
  def index
    set_params
    validate_timezone_requirements

    @leaderboard = find_or_generate_leaderboard

    if @leaderboard.nil?
      flash.now[:notice] = "Leaderboard is being updated..."
    else
      load_entries_and_metadata
    end
  end

  private

  def set_params
    @use_timezone_leaderboard = current_user&.default_timezone_leaderboard
    @period_type = validated_period_type
    @scope = params[:scope] || (@use_timezone_leaderboard ? "regional" : "global")
    @scope_description = scope_description
  end

  def validated_period_type
    period = (params[:period_type] || "daily").to_sym
    valid_periods = [ :daily, :weekly, :last_7_days ]
    valid_periods.include?(period) ? period : :daily
  end

  def scope_description
    case @scope
    when "regional" then current_user&.timezone_offset_name
    when "timezone" then current_user&.timezone
    end
  end

  def validate_timezone_requirements
    return unless regional_or_timezone_scope?

    unless current_user
      flash[:error] = "Please log in to view regional leaderboards!"
      redirect_to leaderboards_path(scope: "global")
      return
    end

    unless current_user.timezone
      flash[:error] = "Please set your timezone in settings to view regional leaderboards"
      redirect_to my_settings_path
      return
    end

    if @scope == "regional" && current_user.timezone_utc_offset.nil?
      flash[:error] = "Unable to determine UTC offset for your timezone: #{current_user.timezone}"
      redirect_to leaderboards_path
    end
  end

  def regional_or_timezone_scope?
    %w[regional timezone].include?(@scope)
  end

  def find_or_generate_leaderboard
    leaderboard = case @scope
    when "regional" then generate_regional_leaderboard
    when "timezone" then generate_timezone_leaderboard
    else find_or_generate_global_leaderboard
    end

    if leaderboard.nil? && %w[regional timezone].include?(@scope)
      @scope = "global"
      @scope_description = nil
      leaderboard = find_or_generate_global_leaderboard
    end

    leaderboard
  end

  def generate_regional_leaderboard
    return nil unless current_user&.timezone_utc_offset

    LeaderboardService.get(
      period: @period_type,
      date: start_date,
      offset: current_user.timezone_utc_offset
    )
  end

  def generate_timezone_leaderboard
    return nil unless current_user&.timezone

    offset = current_user.timezone_utc_offset
    return nil unless offset

    LeaderboardService.get(
      period: @period_type,
      date: start_date,
      offset: offset
    )
  end

  def find_or_generate_global_leaderboard
    LeaderboardService.get(
      period: @period_type,
      date: start_date
    )
  end

  def start_date
    @start_date ||= case @period_type
    when :weekly then Date.current.beginning_of_week
    when :last_7_days then Date.current - 6.days
    else Date.current
    end
  end

  def load_entries_and_metadata
    @entries = @leaderboard.entries

    if @leaderboard.persisted?
      @entries = @entries.includes(:user).order(total_seconds: :desc)
      load_user_tracking_data
    end

    @active_projects = Cache::ActiveProjectsJob.perform_now
  end

  def load_user_tracking_data
    tracked_user_ids = @leaderboard.entries.distinct.pluck(:user_id)
    @user_on_leaderboard = current_user && tracked_user_ids.include?(current_user.id)

    unless @user_on_leaderboard || regional_or_timezone_scope?
      @untracked_entries = calculate_untracked_entries(tracked_user_ids)
    end
  end

  def calculate_untracked_entries(tracked_user_ids)
    time_range = case @period_type
    when :weekly
                   (start_date.beginning_of_day...(start_date + 7.days).beginning_of_day)
    when :last_7_days
                   ((start_date - 6.days).beginning_of_day...start_date.end_of_day)
    else
                   start_date.all_day
    end

    Hackatime::Heartbeat.where(time: time_range)
                        .distinct
                        .pluck(:user_id)
                        .count { |user_id| !tracked_user_ids.include?(user_id) }
  end
end
