class LeaderboardsController < ApplicationController
  PER_PAGE = 100

  def index
    @period_type = validated_period_type
    @leaderboard = LeaderboardService.get(period: @period_type, date: start_date)
    @leaderboard.nil? ? flash.now[:notice] = "Leaderboard is being updated..." : load_metadata
  end

  def entries
    @period_type = validated_period_type
    @leaderboard = LeaderboardService.get(period: @period_type, date: start_date)
    return head :no_content unless @leaderboard&.persisted?

    page = (params[:page] || 1).to_i
    @entries = @leaderboard.entries.includes(:user).order(total_seconds: :desc)
                           .offset((page - 1) * PER_PAGE).limit(PER_PAGE)
    @active_projects = Cache::ActiveProjectsJob.perform_now
    @offset = (page - 1) * PER_PAGE

    render partial: "entries", locals: { entries: @entries, active_projects: @active_projects, offset: @offset }
  end

  private

  def validated_period_type
    p = (params[:period_type] || "daily").to_sym
    %i[daily last_7_days].include?(p) ? p : :daily
  end

  def start_date
    @start_date ||= Date.current
  end

  def load_metadata
    return unless @leaderboard.persisted?

    ids = @leaderboard.entries.distinct.pluck(:user_id)
    @user_on_leaderboard = current_user && ids.include?(current_user.id)
    @untracked_entries = calculate_untracked_entries(ids) unless @user_on_leaderboard
    @total_entries = @leaderboard.entries.count
  end

  def calculate_untracked_entries(ids)
    r = @period_type == :last_7_days ? ((Date.current - 6.days).beginning_of_day...Date.current.end_of_day) : Date.current.all_day
    Hackatime::Heartbeat.where(time: r).where.not(user_id: ids).distinct.count(:user_id)
  end
end
