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
      @total_time_today = @user.heartbeats.today.duration_seconds
      @total_time_week = @user.heartbeats.this_week.duration_seconds
      @total_time_all = @user.heartbeats.duration_seconds

      @top_languages = @user.heartbeats
        .where.not(language: [ nil, "" ])
        .group(:language)
        .duration_seconds
        .sort_by { |_, v| -v }
        .first(5)
        .to_h

      @top_projects = @user.heartbeats
        .group(:project)
        .duration_seconds
        .sort_by { |_, v| -v }
        .first(5)
        .to_h

      project_repo_mappings = @user.project_repo_mappings.index_by(&:project_name)

      @top_projects_month = @user.heartbeats
        .where("time >= ?", 1.month.ago.to_f)
        .group(:project)
        .duration_seconds
        .sort_by { |_, v| -v }
        .first(6)
        .map do |project, duration|
          mapping = project_repo_mappings[project]
          { project: project, duration: duration, repo_url: mapping&.repo_url }
        end

      @top_editors = @user.heartbeats
        .where.not(editor: [ nil, "" ])
        .group(:editor)
        .duration_seconds
        .each_with_object(Hash.new(0)) do |(editor, duration), acc|
          normalized = ApplicationController.helpers.display_editor_name(editor)
          acc[normalized] += duration
        end
        .sort_by { |_, v| -v }
        .first(3)
        .to_h

      @daily_durations = @user.heartbeats.daily_durations(user_timezone: @user.timezone).to_h

      @streak_days = @user.streak_days
      @cool = @user.trust_level == 2
    end
  end
end
