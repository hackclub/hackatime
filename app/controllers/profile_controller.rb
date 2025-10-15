class ProfileController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def my_profile
    @user = current_user
    load_profile_data
    render :show
  end

  def show
    load_profile_data
  end

  private

  def set_user
    return if action_name == 'my_profile' # Skip for my_profile action
    
    # Try to find by numeric ID first, then by slack_uid
    if params[:id] =~ /^\d+$/
      @user = User.find(params[:id])
    else
      @user = User.find_by!(slack_uid: params[:id])
    end
  end

  def load_profile_data
    # Calculate time coded this week
    Time.use_zone(@user.timezone) do
      week_start = Time.current.beginning_of_week
      week_end = Time.current.end_of_week
      
      @this_week_heartbeats = @user.heartbeats.where(time: week_start.to_f..week_end.to_f)
      @this_week_duration = @this_week_heartbeats.duration_seconds
      
      # Get this week's project label activity
      @this_week_project_labels = get_this_week_project_labels(@this_week_heartbeats)
      
      # Get random activity log entries from this week
      @this_week_activity = @this_week_heartbeats
        .order("RANDOM()")
        .limit(5)
    end
    
    # Get all projects data
    @all_labeled_projects = get_all_labeled_projects
    @all_unlabeled_projects = get_all_unlabeled_projects
  end

  def get_this_week_project_labels(week_heartbeats)
    project_labels = @user.project_labels
    return [] if project_labels.empty?
    
    project_times = week_heartbeats.group(:project).duration_seconds
    
    project_labels.map do |label|
      duration = project_times[label.hackatime_project] || 0
      next if duration == 0
      
      {
        label: label,
        name: label.name,
        duration: duration
      }
    end.compact.sort_by { |p| p[:duration] }.reverse
  end

  def get_all_labeled_projects
    project_labels = @user.project_labels
    return [] if project_labels.empty?
    
    project_times = @user.heartbeats.group(:project).duration_seconds
    
    project_labels.map do |label|
      duration = project_times[label.hackatime_project] || 0
      
      {
        label: label,
        name: label.name,
        duration: duration,
        code_url: label.code_url,
        playable_url: label.playable_url,
        description: label.description
      }
    end.sort_by { |p| p[:duration] }.reverse
  end

  def get_all_unlabeled_projects
    labeled_projects = @user.project_labels.pluck(:hackatime_project)
    project_repo_mappings = @user.project_repo_mappings.includes(:repository)
    
    project_times = @user.heartbeats
      .where.not(project: [nil, ""])
      .where.not(project: labeled_projects)
      .group(:project)
      .duration_seconds
    
    project_times.map do |project, duration|
      mapping = project_repo_mappings.find { |p| p.project_name == project }
      {
        project: project || "Unknown",
        repo_url: mapping&.repo_url,
        repository: mapping&.repository,
        duration: duration
      }
    end.filter { |p| p[:duration].positive? }.sort_by { |p| p[:duration] }.reverse
  end
end
