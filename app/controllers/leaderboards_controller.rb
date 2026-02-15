class LeaderboardsController < ApplicationController
  PER_PAGE = 100
  LEADERBOARD_SCOPES = %w[global country].freeze

  def index
    @period_type = validated_period_type
    load_country_context
    @leaderboard_scope = validated_leaderboard_scope
    @leaderboard = LeaderboardService.get(period: @period_type, date: start_date)
    @leaderboard.nil? ? flash.now[:notice] = "Leaderboard is being updated..." : load_metadata
  end

  def entries
    @period_type = validated_period_type
    load_country_context
    @leaderboard_scope = validated_leaderboard_scope
    @leaderboard = LeaderboardService.get(period: @period_type, date: start_date)
    return head :no_content unless @leaderboard&.persisted?

    page = (params[:page] || 1).to_i
    @entries = leaderboard_entries_scope.includes(:user).order(total_seconds: :desc)
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

  def validated_leaderboard_scope
    requested_scope = params[:scope].to_s
    requested_scope = "global" unless LEADERBOARD_SCOPES.include?(requested_scope)
    requested_scope = "global" if requested_scope == "country" && !@country_scope_available
    requested_scope.to_sym
  end

  def load_country_context
    country = ISO3166::Country.new(current_user&.country_code)
    @country_code = country&.alpha2
    @country_name = country&.common_name
    @country_scope_available = @country_code.present? && @country_name.present?
  end

  def country_scope?
    @leaderboard_scope == :country && @country_scope_available
  end

  def leaderboard_entries_scope
    entries_scope = @leaderboard.entries
    return entries_scope unless country_scope?

    entries_scope.joins(:user).where(users: { country_code: @country_code })
  end

  def start_date
    @start_date ||= Date.current
  end

  def load_metadata
    return unless @leaderboard.persisted?

    entries_scope = leaderboard_entries_scope
    ids = entries_scope.distinct.pluck(:user_id)
    @user_on_leaderboard = current_user && ids.include?(current_user.id)
    @untracked_entries = calculate_untracked_entries(ids) unless @user_on_leaderboard || country_scope?
    @total_entries = entries_scope.count
  end

  def calculate_untracked_entries(ids)
    range = @period_type == :last_7_days ? ((Date.current - 6.days).beginning_of_day...Date.current.end_of_day) : Date.current.all_day
    ids_set = ids.to_set

    Hackatime::Heartbeat.where(time: range).distinct.pluck(:user_id).count { |uid| !ids_set.include?(uid) }
  end
end
