class My::ProjectRepoMappingsController < InertiaController
  layout "inertia", only: [ :index ]

  before_action :ensure_current_user
  before_action :require_github_oauth, only: [ :edit, :update ]
  before_action :set_project_repo_mapping_for_edit, only: [ :edit, :update ]
  before_action :set_project_repo_mapping, only: [ :archive, :unarchive ]

  def index
    archived = show_archived?

    render inertia: "Projects/Index", props: {
      page_title: "My Projects",
      index_path: my_projects_path,
      show_archived: archived,
      archived_count: current_user.project_repo_mappings.archived.count,
      github_connected: current_user.github_uid.present?,
      github_auth_path: github_auth_path,
      settings_path: my_settings_path(anchor: "user_github_account"),
      interval: selected_interval,
      from: params[:from],
      to: params[:to],
      interval_label: helpers.human_interval_name(selected_interval, from: params[:from], to: params[:to]),
      total_projects: project_count(archived),
      projects_data: InertiaRails.defer { projects_payload(archived: archived) }
    }
  end

  def edit
  end

  def update
    if @project_repo_mapping.new_record?
      @project_repo_mapping.project_name = CGI.unescape(params[:project_name])
    end

    if @project_repo_mapping.update(project_repo_mapping_params)
      redirect_to my_projects_path, notice: "Repository mapping updated successfully."
    else
      flash.now[:alert] = @project_repo_mapping.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    @project_repo_mapping.archive!
    redirect_to my_projects_path, notice: "Away it goes!"
  end

  def unarchive
    @project_repo_mapping.unarchive!
    r = current_user.project_repo_mappings.archived.where.not(id: @project_repo_mapping.id).exists?
    p = r ? my_projects_path(show_archived: true) : my_projects_path
    redirect_to p, notice: "Back from the dead!"
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

  def set_project_repo_mapping_for_edit
    decoded_project_name = CGI.unescape(params[:project_name])
    @project_repo_mapping = current_user.project_repo_mappings.find_or_initialize_by(
      project_name: decoded_project_name
    )
  end

  def set_project_repo_mapping
    decoded_project_name = CGI.unescape(params[:project_name])
    @project_repo_mapping = current_user.project_repo_mappings.find_or_create_by!(
      project_name: decoded_project_name
    )
  end

  def project_repo_mapping_params
    params.require(:project_repo_mapping).permit(:repo_url)
  end

  def show_archived?
    params[:show_archived] == "true"
  end

  def selected_interval
    params[:interval]
  end

  def project_durations_cache_key
    key = "user_#{current_user.id}_project_durations_#{selected_interval}_v3"
    if selected_interval == "custom"
      sanitized_from = sanitized_cache_date(params[:from]) || "none"
      sanitized_to = sanitized_cache_date(params[:to]) || "none"
      key += "_#{sanitized_from}_#{sanitized_to}"
    end
    key
  end

  def sanitized_cache_date(value)
    value.to_s.gsub(/[^0-9-]/, "")[0, 10].presence
  end

  def projects_payload(archived:)
    mappings = current_user.project_repo_mappings.includes(:repository)
    scoped_mappings = archived ? mappings.archived : mappings.active
    mappings_by_name = scoped_mappings.index_by(&:project_name)
    repository_ids = scoped_mappings.where.not(repository_id: nil).distinct.pluck(:repository_id)
    latest_user_commit_at_by_repo_id = Commit.where(user_id: current_user.id, repository_id: repository_ids)
                                             .group(:repository_id)
                                             .maximum(:created_at)
    archived_names = current_user.project_repo_mappings.archived.pluck(:project_name).index_with(true)
    labels_by_project_key = Flipper.enabled?(:hackatime_v1_import) ? current_user.project_labels.pluck(:project_key, :label).to_h : {}

    cached = Rails.cache.fetch(project_durations_cache_key, expires_in: 1.minute) do
      hb = current_user.heartbeats.filter_by_time_range(selected_interval, params[:from], params[:to])
      {
        durations: hb.group(:project).duration_seconds,
        total_time: hb.duration_seconds
      }
    end

    projects = cached[:durations].filter_map do |project_key, duration|
      next if duration <= 0
      next if archived_names.key?(project_key) != archived

      mapping = mappings_by_name[project_key]
      display_name = labels_by_project_key[project_key].presence || project_key.presence || "Unknown"

      {
        id: project_card_id(project_key),
        name: display_name,
        project_key: project_key,
        duration_seconds: duration,
        duration_label: format_duration(duration),
        duration_percent: 0,
        repo_url: mapping&.repo_url,
        repository: repository_payload(mapping&.repository, latest_user_commit_at_by_repo_id),
        broken_name: broken_project_name?(project_key, display_name),
        manage_enabled: current_user.github_uid.present? && project_key.present?,
        edit_path: project_key.present? ? edit_my_project_repo_mapping_path(CGI.escape(project_key)) : nil,
        update_path: project_key.present? ? my_project_repo_mapping_path(CGI.escape(project_key)) : nil,
        archive_path: project_key.present? ? archive_my_project_repo_mapping_path(CGI.escape(project_key)) : nil,
        unarchive_path: project_key.present? ? unarchive_my_project_repo_mapping_path(CGI.escape(project_key)) : nil
      }
    end.sort_by { |project| -project[:duration_seconds] }

    max_duration = projects.map { |project| project[:duration_seconds].to_f }.max || 1.0

    projects.each do |project|
      project[:duration_percent] = ((project[:duration_seconds].to_f / max_duration) * 100).round(1)
    end

    total_time = cached[:total_time].to_i

    {
      total_time_seconds: total_time,
      total_time_label: format_duration(total_time),
      has_activity: total_time.positive?,
      projects: projects
    }
  end

  def format_duration(seconds)
    helpers.short_time_detailed(seconds).presence || "0m"
  end

  def project_card_id(project_key)
    raw_key = project_key.nil? ? "__nil__" : "str:#{project_key}"
    "project-#{raw_key.unpack1('H*')}"
  end

  def broken_project_name?(project_key, display_name)
    key = project_key.to_s
    name = display_name.to_s

    key.blank? || name.downcase == "unknown" || key.match?(/<<.*>>/) || name.match?(/<<.*>>/)
  end

  def repository_payload(repository, latest_user_commit_at_by_repo_id = {})
    return nil unless repository

    last_commit_at = effective_last_commit_at(repository, latest_user_commit_at_by_repo_id)

    {
      homepage: repository.homepage,
      stars: repository.stars,
      description: repository.description,
      formatted_languages: repository.formatted_languages,
      last_commit_ago: last_commit_at ? "#{helpers.time_ago_in_words(last_commit_at)} ago" : nil
    }
  end

  def effective_last_commit_at(repository, latest_user_commit_at_by_repo_id)
    [ repository.last_commit_at, latest_user_commit_at_by_repo_id[repository.id] ].compact.max
  end

  def project_count(archived)
    archived_names = current_user.project_repo_mappings.archived.pluck(:project_name)
    hb = current_user.heartbeats.filter_by_time_range(selected_interval, params[:from], params[:to])
    projects = hb.select(:project).distinct.pluck(:project)
    projects.count { |proj| archived_names.include?(proj) == archived }
  end
end
