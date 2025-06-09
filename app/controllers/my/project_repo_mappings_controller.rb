class My::ProjectRepoMappingsController < ApplicationController
  before_action :ensure_current_user
  before_action :require_github_oauth, only: [ :edit, :update ]
  before_action :set_project_repo_mapping, only: [ :edit, :update ]

  def index
    @project_repo_mappings = current_user.project_repo_mappings || []
    @interval = params[:interval] || "daily"
    @from = params[:from]
    @to = params[:to]
  end

  def edit
  end

  def update
    if @project_repo_mapping.new_record?
      @project_repo_mapping.project_name = params[:project_name]
    end

    if @project_repo_mapping.update(project_repo_mapping_params)
      redirect_to my_project_repo_mapping_path, notice: "Repository mapping updated successfully."
    else
      flash.now[:alert] = @project_repo_mapping.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def ensure_current_user
    redirect_to root_path, alert: "You must be logged in to view this page" unless current_user
  end

  def require_github_oauth
    unless current_user.github_uid.present?
      flash[:alert] = "Please connect your GitHub account to map repositories."
      redirect_to my_projects_path
    end
  end

  def set_project_repo_mapping
    @project_repo_mapping = current_user.project_repo_mappings.find_or_initialize_by(
      project_name: params[:project_name]
    )
  end

  def project_repo_mapping_params
    params.require(:project_repo_mapping).permit(:repo_url)
  end
end
