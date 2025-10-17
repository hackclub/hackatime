class My::ProjectsController < ApplicationController
  layout :resolve_layout
  
  before_action :ensure_current_user

  def index
    @user = current_user
    @project_repo_mappings = current_user.project_repo_mappings.includes(:repository)
    @interval = params[:interval] || "daily"
    @from = params[:from]
    @to = params[:to]
    
    # Get project labels for the current user
    @project_labels = current_user.project_labels
    
    # Get project durations for labeled projects
    @labeled_project_durations = get_labeled_project_durations
    
    # Calculate totals for sidebar stats
    overall = current_user.heartbeats.filter_by_time_range(@interval, @from, @to).duration_seconds
    labeled_total = @labeled_project_durations.sum { |p| p[:duration] }
    @overall_duration = overall
    @labeled_total = labeled_total
    @unlabeled_total = [overall - labeled_total, 0].max
    
    render 'projects/index'
  end

  def new
    @project_label = current_user.project_labels.build
    @project_label.hackatime_project = params[:hackatime_project] if params[:hackatime_project].present?
    @available_projects = get_available_hackatime_projects
    
    render 'projects/new'
  end

  def project_stats
    project_name = params[:project]
    return render json: { error: "No project specified" }, status: :bad_request if project_name.blank?

    Time.use_zone(current_user.timezone) do
      # Get all heartbeats for this project
      project_heartbeats = current_user.heartbeats.where(project: project_name)
      
      # Total time
      total_time = project_heartbeats.duration_seconds
      
      # Time this week
      week_start = Time.current.beginning_of_week
      week_heartbeats = project_heartbeats.where("time >= ?", week_start.to_f)
      week_time = week_heartbeats.duration_seconds
      
      # Language stats
      language_stats = project_heartbeats
        .group(:language)
        .duration_seconds
        .reject { |lang, _| lang.blank? }
        .sort_by { |_, duration| -duration }
        .first(10)
        .to_h

      render json: {
        total_time: total_time,
        week_time: week_time,
        language_stats: language_stats
      }
    end
  end

  def create
    @project_label = current_user.project_labels.build(project_label_params)
    
    if @project_label.save
      redirect_to user_project_path(current_user.slack_uid.present? ? current_user.slack_uid : current_user.id, @project_label.id), notice: "Project label created successfully!"
    else
      @available_projects = get_available_hackatime_projects
      render 'projects/new', status: :unprocessable_entity
    end
  end

  def edit
    @project_label = current_user.project_labels.find(params[:id])
    @available_projects = get_available_hackatime_projects(@project_label.hackatime_project)
    
    render 'projects/edit'
  end

  def update
    @project_label = current_user.project_labels.find(params[:id])
    
    if @project_label.update(project_label_params)
      redirect_to user_project_path(current_user.slack_uid.present? ? current_user.slack_uid : current_user.id, @project_label.id), notice: "Project label updated successfully!"
    else
      @available_projects = get_available_hackatime_projects(@project_label.hackatime_project)
      render 'projects/edit', status: :unprocessable_entity
    end
  end

  def destroy
    @project_label = current_user.project_labels.find(params[:id])
    @project_label.destroy
    redirect_to my_projects_path, notice: "Project label deleted successfully!"
  end

  def project_durations
    @project_repo_mappings = current_user.project_repo_mappings.includes(:repository)
    cache_key = "user_#{current_user.id}_project_durations_#{params[:interval]}"
    cache_key += "_#{params[:from]}_#{params[:to]}" if params[:interval] == "custom"

    project_durations = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      heartbeats = current_user.heartbeats.filter_by_time_range(params[:interval], params[:from], params[:to])
      project_times = heartbeats.group(:project).duration_seconds
      project_labels = current_user.project_labels
      labeled_projects = project_labels.pluck(:hackatime_project)
      
      project_times.filter_map do |project, duration|
        # Skip labeled projects - only show unlabeled ones
        next if labeled_projects.include?(project)
        
        mapping = @project_repo_mappings.find { |p| p.project_name == project }
        {
          project: project || "Unknown",
          repo_url: mapping&.repo_url,
          repository: mapping&.repository,
          duration: duration
        }
      end.filter { |p| p[:duration].positive? }.sort_by { |p| p[:duration] }.reverse
    end
    render partial: "projects/project_durations", locals: { project_durations: project_durations }
  end

  private

  def ensure_current_user
    redirect_to root_path, alert: "You must be logged in to view this page" unless current_user
  end

  def project_label_params
    params.require(:project_label).permit(:name, :description, :playable_url, :code_url, :hackatime_project)
  end

  def get_labeled_project_durations
    return [] if @project_labels.empty?
    
    cache_key = "user_#{current_user.id}_labeled_project_durations_#{@interval}"
    cache_key += "_#{@from}_#{@to}" if @interval == "custom"
    
    Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      @project_labels.map do |label|
        heartbeats = current_user.heartbeats
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

  def get_available_hackatime_projects(include_project = nil)
    # Get all unique project names from user's heartbeats, excluding ones already labeled
    labeled_projects = current_user.project_labels.pluck(:hackatime_project)
    
    # If we're editing, don't exclude the current project from the list
    labeled_projects -= [include_project] if include_project.present?
    
    current_user.heartbeats
      .select(:project)
      .distinct
      .where.not(project: [nil, ""])
      .where.not(project: labeled_projects)
      .order(:project)
      .pluck(:project)
  end

  def resolve_layout
    %w[index new edit].include?(action_name) ? "homepage" : "application"
  end
end
