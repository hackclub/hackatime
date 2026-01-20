class ProfilesController < ApplicationController
  def show
    @user = find(params[:username])

    if @user.nil?
      render :not_found, status: :not_found, formats: [ :html ]
      return
    end

    @is_own_profile = current_user && current_user.id == @user.id
    @profile_visible = @user.allow_public_stats_lookup || @is_own_profile

    return unless @profile_visible

    load
  end

  private

  def find(username)
    User.find_by(username: username)
  end

  def load
    Time.use_zone(@user.timezone) do
      stats = ProfileStatsService.new(@user).stats

      @total_time_today = stats[:total_time_today]
      @total_time_week = stats[:total_time_week]
      @total_time_all = stats[:total_time_all]
      @top_languages = stats[:top_languages]
      @top_projects = stats[:top_projects]
      @top_projects_month = stats[:top_projects_month]
      @top_editors = stats[:top_editors]

      @daily_durations = @user.heartbeats.daily_durations(user_timezone: @user.timezone).to_h

      @streak_days = @user.streak_days
      @cool = @user.trust_level == 2
    end
  end
end
