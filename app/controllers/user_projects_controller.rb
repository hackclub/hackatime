class UserProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :set_project_label, only: [:show]

  def index
    @project_labels = @user.project_labels
    @interval = params[:interval] || "daily"
    @from = params[:from]
    @to = params[:to]
    
    # Get project durations for labeled projects
    @labeled_project_durations = get_labeled_project_durations
    
    render 'projects/index'
  end

  def show
    @project_name = @project_label.hackatime_project
    @project_heartbeats = @user.heartbeats.where(project: @project_name)
    @project_author = @project_label.user
    
    # Get project statistics
    @total_duration = @project_heartbeats.duration_seconds
    
    # Calculate time coded this week
    Time.use_zone(@user.timezone) do
      week_start = Time.current.beginning_of_week
      week_end = Time.current.end_of_week
      
      @this_week_heartbeats = @project_heartbeats.where(time: week_start.to_f..week_end.to_f)
      @this_week_duration = @this_week_heartbeats.duration_seconds
    end
    
    # Calculate days worked
    @days_worked = @project_heartbeats
      .group("DATE(to_timestamp(time))")
      .count
      .size
    
    # Get recent activity
    @recent_activity = @project_heartbeats
      .order(time: :desc)
      .limit(10)
    
    # Get language breakdown
    @language_stats = @project_heartbeats
      .where.not(language: [nil, ""])
      .group(:language)
      .duration_seconds
      .sort_by { |_, duration| -duration }
      .first(5)
      .to_h
    
    # Get recent commits if project has repository mapping
    @recent_commits = get_recent_commits
      
    render 'projects/show'
  end

  private

  def set_user
    # Try to find by numeric ID first, then by slack_uid
    if params[:user_id] =~ /^\d+$/
      @user = User.find(params[:user_id])
    else
      @user = User.find_by!(slack_uid: params[:user_id])
    end
  end

  def set_project_label
    @project_label = @user.project_labels.find(params[:id])
  end

  def get_labeled_project_durations
    return [] if @project_labels.empty?
    
    cache_key = "user_#{@user.id}_labeled_project_durations_#{@interval}"
    cache_key += "_#{@from}_#{@to}" if @interval == "custom"
    
    Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      @project_labels.map do |label|
        heartbeats = @user.heartbeats
          .where(project: label.hackatime_project)
          .filter_by_time_range(@interval, @from, @to)
        
        duration = heartbeats.duration_seconds
        
        {
          label: label,
          project: label.name,
          duration: duration,
          code_url: label.code_url,
          playable_url: label.playable_url,
          description: label.description
        }
      end.filter { |p| p[:duration].positive? }.sort_by { |p| p[:duration] }.reverse
    end
  end

  def get_recent_commits
    # Use repository URL from project label's code_url
    return [] unless @project_label.code_url.present?
    
    # Find or create repository by URL
    repository = Repository.find_or_create_by_url(@project_label.code_url)
    return [] unless repository
    
    # Get recent commits from the repository
    commits = repository.commits.order(created_at: :desc).limit(3)
    Rails.logger.info "Commits found: #{commits.count}, Repository ID: #{repository.id}"
    
    # Calculate time logged for each commit
    commits.map do |commit|
      # Get commit time and previous commit time to calculate time window
      commit_time = commit.created_at
      previous_commit = repository.commits
        .where('created_at < ?', commit_time)
        .order(created_at: :desc)
        .first
      
      # Calculate time window (from previous commit to this commit)
      start_time = previous_commit ? previous_commit.created_at : commit_time - 7.days
      end_time = commit_time
      
      # Get heartbeats in that time window for this project
      time_logged = @project_heartbeats
        .where(time: start_time.to_f..end_time.to_f)
        .duration_seconds
      
      {
        commit: commit,
        time_logged: time_logged,
        commit_time: commit_time
      }
    end
  end
end
