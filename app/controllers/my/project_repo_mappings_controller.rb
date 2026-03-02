class My::ProjectRepoMappingsController < InertiaController
  layout "inertia", only: [ :index, :show ]

  before_action :ensure_current_user
  before_action :require_github_oauth, only: [ :edit, :update ]
  before_action :set_project_repo_mapping_for_edit, only: [ :edit, :update ]
  before_action :set_project_repo_mapping, only: [ :archive, :unarchive, :toggle_share ]

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
      back_path: my_projects_path,
      since_date: since_date,
      repo_url: mapping&.repo_url,
      is_shared: mapping&.public_shared_at.present?,
      share_url: share_url,
      toggle_share_path: toggle_share_my_project_repo_mapping_path(CGI.escape(project_name)),
      interval: selected_interval,
      from: params[:from],
      to: params[:to],
      project_stats: InertiaRails.defer { project_detail_payload(project_name) }
    }
  end

  def toggle_share
    if @project_repo_mapping.public_shared_at.present?
      @project_repo_mapping.update_column(:public_shared_at, nil)
      redirect_back fallback_location: my_projects_path, notice: "Project is now private."
    else
      @project_repo_mapping.update_column(:public_shared_at, Time.current)
      redirect_back fallback_location: my_projects_path, notice: "Project is now shared!"
    end
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

  def project_detail_payload(project_name)
    h = ApplicationController.helpers
    hb = current_user.heartbeats.where(project: project_name)
      .filter_by_time_range(selected_interval, params[:from], params[:to])

    total_time = hb.duration_seconds

    language_stats = hb.group(:language).duration_seconds.each_with_object({}) do |(raw, dur), agg|
      k = raw.to_s.presence || "Unknown"
      k = k == "Unknown" ? k : k.categorize_language
      agg[k] = (agg[k] || 0) + dur
    end.sort_by { |_, d| -d }.first(15).to_h

    editor_stats = hb.group(:editor).duration_seconds.each_with_object({}) do |(raw, dur), agg|
      k = raw.to_s.presence || "Unknown"
      agg[k.downcase] = (agg[k.downcase] || 0) + dur
    end.sort_by { |_, d| -d }.first(10).map { |k, v| [ h.display_editor_name(k), v ] }.to_h

    os_stats = hb.group(:operating_system).duration_seconds.each_with_object({}) do |(raw, dur), agg|
      k = raw.to_s.presence || "Unknown"
      agg[k.downcase] = (agg[k.downcase] || 0) + dur
    end.sort_by { |_, d| -d }.first(10).map { |k, v| [ h.display_os_name(k), v ] }.to_h

    all_file_stats = hb.group(:entity).duration_seconds
      .reject { |e, dur| e.blank? || dur < 60 }
      .sort_by { |_, d| -d }

    file_stats = all_file_stats.first(50)
      .map { |entity, dur| [ shorten_file_path(entity), dur ] }

    branch_stats = hb.group(:branch).duration_seconds
      .reject { |b, _| b.blank? }
      .sort_by { |_, d| -d }.first(10)

    category_stats = hb.group(:category).duration_seconds.each_with_object({}) do |(raw, dur), agg|
      k = raw.to_s.presence || "Unknown"
      agg[k] = (agg[k] || 0) + dur
    end.sort_by { |_, d| -d }.first(10).to_h

    language_colors = language_stats.present? ? LanguageUtils.colors_for(language_stats.keys) : {}

    activity_data = project_activity_graph(project_name)

    {
      total_time: total_time,
      total_time_label: format_duration(total_time),
      language_count: language_stats.size,
      branch_count: branch_stats.size,
      file_count: hb.select(:entity).distinct.count,
      language_stats: language_stats,
      language_colors: language_colors,
      editor_stats: editor_stats,
      os_stats: os_stats,
      category_stats: category_stats,
      file_stats: file_stats,
      branch_stats: branch_stats,
      activity_graph: activity_data
    }
  end

  def shorten_file_path(entity)
    return entity if entity.blank?
    parts = entity.split("/")
    return entity if parts.length <= 3
    "#{parts.first}/…/#{parts.last(2).join("/")}"
  end

  def project_activity_graph(project_name)
    tz = current_user.timezone
    hb = current_user.heartbeats.where(project: project_name)

    day_trunc = Arel.sql("DATE_TRUNC('day', to_timestamp(time) AT TIME ZONE '#{tz}')")

    durations = hb.select(day_trunc.as("day_group"))
      .where(time: 365.days.ago..Time.current)
      .group(day_trunc)
      .duration_seconds
      .map { |date, duration| [ date.to_date.iso8601, duration ] }
      .to_h

    {
      start_date: 365.days.ago.to_date.iso8601,
      end_date: Time.current.to_date.iso8601,
      duration_by_date: durations,
      busiest_day_seconds: 8.hours.to_i,
      timezone_label: ActiveSupport::TimeZone[tz].to_s,
      timezone_settings_path: "/my/settings#user_timezone"
    }
  end
end
