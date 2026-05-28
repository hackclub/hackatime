class My::ProjectRepoMappingsController < InertiaController
  layout "inertia", only: [ :index, :show ]

  before_action :ensure_current_user
  before_action :require_github_oauth, only: [ :edit, :update ]
  before_action :set_project_repo_mapping_for_edit, only: [ :edit, :update ]
  before_action :set_project_repo_mapping, only: [ :archive, :unarchive, :toggle_share ]

  def index
    archived = show_archived?
    projects_data = projects_data_for_index(archived: archived)

    render inertia: "Projects/Index", props: {
      page_title: "My Projects",
      show_archived: archived,
      archived_count: current_user.project_repo_mappings.archived.count,
      github_connected: current_user.github_uid.present?,
      interval: selected_interval,
      from: params[:from],
      to: params[:to],
      interval_label: helpers.human_interval_name(selected_interval, from: params[:from], to: params[:to]),
      total_projects: projects_data.is_a?(Hash) ? projects_data[:projects].size : project_count(archived),
      projects_data: projects_data
    }
  end

  def edit; end

  def update
    @project_repo_mapping.project_name = params[:project_name] if @project_repo_mapping.new_record?

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

  def show
    project_name = CGI.unescape(params[:project_name])
    mapping = current_user.project_repo_mappings.find_by(project_name: project_name)
    first_heartbeat = current_user.heartbeats.where(project: project_name).minimum(:time)
    since_date = first_heartbeat ? Time.at(first_heartbeat).to_date.strftime("%-m/%-d/%Y") : nil

    share_url = if mapping&.public_shared_at.present? && current_user.username.present?
      profile_project_url(username: current_user.username, project_name: CGI.escape(project_name))
    end

    render inertia: "Projects/Show", props: {
      page_title: "#{project_name} | My Projects",
      project_name: project_name,
      since_date: since_date,
      repo_url: mapping&.repo_url,
      is_shared: mapping&.public_shared_at.present?,
      share_url: share_url,
      interval: selected_interval,
      from: params[:from],
      to: params[:to],
      project_stats: InertiaRails.defer { project_detail_payload(project_name) }
    }
  end

  def toggle_share
    new_val = @project_repo_mapping.public_shared_at.present? ? nil : Time.current
    @project_repo_mapping.update_column(:public_shared_at, new_val)
    notice = new_val ? "Project is now shared!" : "Project is now private."
    redirect_back fallback_location: my_projects_path, notice: notice
  end

  def unarchive
    @project_repo_mapping.unarchive!
    has_other = current_user.project_repo_mappings.archived.where.not(id: @project_repo_mapping.id).exists?
    redirect_to (has_other ? my_projects_path(show_archived: true) : my_projects_path), notice: "Back from the dead!"
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
    @project_repo_mapping = current_user.project_repo_mappings.find_or_initialize_by(project_name: params[:project_name])
  end

  def set_project_repo_mapping
    @project_repo_mapping = current_user.project_repo_mappings.find_or_create_by!(project_name: params[:project_name])
  end

  def project_repo_mapping_params = params.require(:project_repo_mapping).permit(:repo_url)
  def show_archived? = params[:show_archived] == "true"
  def selected_interval = params[:interval]

  def project_durations_cache_key
    key = "user_#{current_user.id}_project_durations_#{selected_interval}_v3"
    if selected_interval == "custom"
      sanitized_from = sanitized_cache_date(params[:from]) || "none"
      sanitized_to = sanitized_cache_date(params[:to]) || "none"
      key += "_#{sanitized_from}_#{sanitized_to}"
    end
    key
  end

  def sanitized_cache_date(value) = value.to_s.gsub(/[^0-9-]/, "")[0, 10].presence

  # Builds the data needed for either projects_payload or rollup_projects_payload:
  # scoped mappings, archived name set, and latest commit timestamps by repo id.
  def projects_context(archived:)
    mappings = current_user.project_repo_mappings.includes(:repository)
    scoped_mappings = archived ? mappings.archived : mappings.active
    mappings_by_name = scoped_mappings.index_by(&:project_name)
    repository_ids = scoped_mappings.where.not(repository_id: nil).distinct.pluck(:repository_id)
    latest_user_commit_at_by_repo_id = Commit.where(user_id: current_user.id, repository_id: repository_ids)
                                             .group(:repository_id).maximum(:created_at)
    archived_names = current_user.project_repo_mappings.archived.pluck(:project_name).index_with(true)

    [ mappings_by_name, archived_names, latest_user_commit_at_by_repo_id ]
  end

  def projects_payload(archived:)
    mappings_by_name, archived_names, latest_user_commit_at_by_repo_id = projects_context(archived: archived)

    cached = Rails.cache.fetch(project_durations_cache_key, expires_in: 1.minute) do
      hb = current_user.heartbeats.filter_by_time_range(selected_interval, params[:from], params[:to])
      { durations: hb.group(:project).duration_seconds, total_time: hb.duration_seconds }
    end

    projects = cached[:durations].filter_map do |project_key, duration|
      next if duration <= 0
      next if archived_names.key?(project_key) != archived

      project_summary_payload(project_key, duration, mappings_by_name[project_key], latest_user_commit_at_by_repo_id)
    end.sort_by { |project| -project[:duration_seconds] }

    build_projects_payload(projects)
  end

  def projects_data_for_index(archived:)
    return empty_projects_payload unless current_user.heartbeats.exists?
    return rollup_projects_payload(archived: archived) if rollup_projects_path?

    InertiaRails.defer { projects_payload(archived: archived) }
  end

  def empty_projects_payload
    { total_time_seconds: 0, total_time_label: format_duration(0), has_activity: false, projects: [] }
  end

  def rollup_projects_path? = selected_interval.blank? && params[:from].blank? && params[:to].blank?

  def rollup_projects_payload(archived:)
    rollups = DashboardRollup
      .where(user_id: current_user.id, dimension: DashboardRollup::PROJECT_DETAILS_DIMENSION, bucket_value_present: true)
      .to_a

    DashboardRollupRefreshJob.schedule_for(current_user.id, wait: 0.seconds) if DashboardRollup.dirty?(current_user.id) || rollups.empty?
    return InertiaRails.defer { projects_payload(archived: archived) } if rollups.empty?

    mappings_by_name, archived_names, latest_user_commit_at_by_repo_id = projects_context(archived: archived)

    projects = rollups.filter_map do |rollup|
      project_key = rollup.bucket
      next if project_key.blank?
      next if archived_names.key?(project_key) != archived

      duration = rollup.total_seconds.to_i
      next if duration <= 0

      project_summary_payload(project_key, duration, mappings_by_name[project_key], latest_user_commit_at_by_repo_id)
    end.sort_by { |project| -project[:duration_seconds] }

    build_projects_payload(projects)
  end

  def project_summary_payload(project_key, duration, mapping, latest_user_commit_at_by_repo_id)
    display_name = project_key.presence || "Unknown"
    broken = broken_project_name?(project_key, display_name)
    url_safe = !broken && project_key.present?

    {
      id: project_card_id(project_key),
      name: display_name,
      project_key:,
      url_safe:,
      duration_seconds: duration,
      duration_label: format_duration(duration),
      duration_percent: 0,
      repo_url: mapping&.repo_url,
      repository: repository_payload(mapping&.repository, latest_user_commit_at_by_repo_id),
      broken_name: broken,
      manage_enabled: current_user.github_uid.present? && url_safe
    }
  end

  def build_projects_payload(projects)
    max_duration = projects.map { |project| project[:duration_seconds].to_f }.max || 1.0
    projects.each { |p| p[:duration_percent] = ((p[:duration_seconds].to_f / max_duration) * 100).round(1) }
    total_time = projects.sum { |p| p[:duration_seconds] }

    { total_time_seconds: total_time, total_time_label: format_duration(total_time),
      has_activity: total_time.positive?, projects: projects }
  end

  def format_duration(seconds) = helpers.short_time_detailed(seconds).presence || "0m"

  def project_card_id(project_key)
    raw_key = project_key.nil? ? "__nil__" : "str:#{project_key}"
    "project-#{raw_key.unpack1('H*')}"
  end

  def broken_project_name?(project_key, display_name)
    ProjectNameUtils.broken?(project_key, display_name)
  end

  def repository_payload(repository, latest_user_commit_at_by_repo_id = {})
    return nil unless repository

    last_commit_at = [ repository.last_commit_at, latest_user_commit_at_by_repo_id[repository.id] ].compact.max

    {
      homepage: repository.homepage,
      stars: repository.stars,
      description: repository.description,
      formatted_languages: repository.formatted_languages,
      last_commit_ago: last_commit_at ? "#{helpers.time_ago_in_words(last_commit_at)} ago" : nil
    }
  end

  def project_count(archived)
    archived_names = current_user.project_repo_mappings.archived.pluck(:project_name)
    hb = current_user.heartbeats.filter_by_time_range(selected_interval, params[:from], params[:to])
    projects = hb.select(:project).distinct.pluck(:project)
    projects.count { |proj| archived_names.include?(proj) == archived }
  end

  def project_detail_payload(project_name)
    h = ApplicationController.helpers
    hb = current_user.heartbeats.where(project: project_name)
      .filter_by_time_range(selected_interval, params[:from], params[:to])

    total_time = hb.duration_seconds

    grouped = ->(field, n, normalize: ->(k) { k.to_s }, display: nil) {
      result = Heartbeat.attributed_durations_by(hb, field).each_with_object({}) do |(raw, dur), agg|
        k = normalize.call(raw)
        agg[k] = (agg[k] || 0) + dur
      end.sort_by { |_, d| -d }.first(n)
      display ? result.map { |k, v| [ display.call(k), v ] }.to_h : result.to_h
    }

    language_stats = grouped.call(:language, 15, normalize: ->(k) { k.to_s.categorize_language })
    editor_stats = grouped.call(:editor, 10, normalize: ->(k) { k.to_s.downcase }, display: ->(k) { h.display_editor_name(k) })
    os_stats = grouped.call(:operating_system, 10, normalize: ->(k) { k.to_s.downcase }, display: ->(k) { h.display_os_name(k) })

    all_file_stats = Heartbeat.attributed_durations_by(hb, :entity).reject { |_, dur| dur < 60 }.sort_by { |_, d| -d }
    file_stats = all_file_stats.first(50).map { |entity, dur| [ helpers.shorten_file_path(entity), dur ] }

    branch_stats = Heartbeat.attributed_durations_by(hb, :branch).sort_by { |_, d| -d }.first(10)
    category_stats = Heartbeat.attributed_durations_by(hb, :category).sort_by { |_, d| -d }.first(10).to_h

    language_colors = language_stats.present? ? LanguageUtils.colors_for(language_stats.keys) : {}

    {
      total_time: total_time,
      total_time_label: format_duration(total_time),
      file_count: hb.select(:entity).distinct.count,
      language_stats: language_stats,
      language_colors: language_colors,
      editor_stats: editor_stats,
      os_stats: os_stats,
      category_stats: category_stats,
      file_stats: file_stats,
      branch_stats: branch_stats,
      activity_graph: project_activity_graph(project_name)
    }
  end

  def project_activity_graph(project_name)
    snapshot = DashboardData::Snapshots.activity_graph_snapshot(
      user: current_user, scope: current_user.heartbeats.where(project: project_name)
    )
    DashboardData::Snapshots.activity_graph_result(
      start_date: snapshot[:start_date],
      end_date: snapshot[:end_date],
      duration_by_date: snapshot[:duration_by_date],
      timezone: snapshot[:timezone]
    )
  end
end
