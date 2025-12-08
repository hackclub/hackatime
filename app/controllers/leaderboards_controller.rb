class LeaderboardsController < ApplicationController
  def index
    set_params

    @leaderboard = find_or_generate_leaderboard

    if @leaderboard.nil?
      flash.now[:notice] = "Leaderboard is being updated..."
    else
      load_entries_and_metadata
    end
  end

  private

  def set_params
    @period_type = validated_period_type
  end

  def validated_period_type
    period = (params[:period_type] || "daily").to_sym
    valid_periods = [ :daily, :last_7_days ]
    valid_periods.include?(period) ? period : :daily
  end

  def find_or_generate_leaderboard
    LeaderboardService.get(
      period: @period_type,
      date: start_date
    )
  end

  def start_date
    @start_date ||= case @period_type
    when :last_7_days then Date.current
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

    unless @user_on_leaderboard
      @untracked_entries = calculate_untracked_entries(tracked_user_ids)
    end
  end

  def calculate_untracked_entries(tracked_user_ids)
    time_range = case @period_type
    when :last_7_days
                   ((Date.current - 6.days).beginning_of_day...Date.current.end_of_day)
    else
                   Date.current.all_day
    end

    Hackatime::Heartbeat.where(time: time_range)
                        .distinct
                        .pluck(:user_id)
                        .count { |user_id| !tracked_user_ids.include?(user_id) }
  end
end
