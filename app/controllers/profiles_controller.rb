class ProfilesController < ApplicationController
  before_action :find_user
  before_action :check_profile_visibility, only: %i[time_stats projects languages editors activity]

  def show
    if @user.nil?
      render :not_found, status: :not_found, formats: [ :html ]
      return
    end

    @is_own_profile = current_user && current_user.id == @user.id
    @profile_visible = @user.allow_public_stats_lookup || @is_own_profile
    @streak_days = @user.streak_days if @profile_visible
  end

  def time_stats
    Time.use_zone(@user.timezone) do
      stats = ProfileStatsService.new(@user).stats
      render partial: "profiles/time_stats", locals: {
        total_time_today: stats[:total_time_today],
        total_time_week: stats[:total_time_week],
        total_time_all: stats[:total_time_all]
      }
    end
  end

  def projects
    Time.use_zone(@user.timezone) do
      stats = ProfileStatsService.new(@user).stats
      render partial: "profiles/projects", locals: { projects: stats[:top_projects_month] }
    end
  end

  def languages
    Time.use_zone(@user.timezone) do
      stats = ProfileStatsService.new(@user).stats
      render partial: "profiles/languages", locals: { languages: stats[:top_languages] }
    end
  end

  def editors
    Time.use_zone(@user.timezone) do
      stats = ProfileStatsService.new(@user).stats
      render partial: "profiles/editors", locals: { editors: stats[:top_editors] }
    end
  end

  def activity
    Time.use_zone(@user.timezone) do
      daily_durations = @user.heartbeats.daily_durations(user_timezone: @user.timezone).to_h
      render partial: "profiles/activity", locals: { daily_durations: daily_durations, user_tz: @user.timezone }
    end
  end

  private

  def find_user
    @user = User.find_by(username: params[:username])
  end

  def check_profile_visibility
    return if @user.nil?

    is_own_profile = current_user && current_user.id == @user.id
    profile_visible = @user.allow_public_stats_lookup || is_own_profile

    head :not_found unless profile_visible
  end
end
