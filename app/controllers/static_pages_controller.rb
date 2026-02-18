class StaticPagesController < InertiaController
  include DashboardData

  layout "inertia", only: %i[index wakatime_alternative]

  def index
    if current_user
      flavor_texts = FlavorText.motto + FlavorText.conditional_mottos(current_user)
      flavor_texts += FlavorText.rare_motto if Random.rand(10) < 1
      @flavor_text = flavor_texts.sample

      if params[:date].present?
        d = Date.parse(params[:date]) rescue nil
        return redirect_to "/my/projects?interval=custom&from=#{d}&to=#{d}" if d
      end

      if !current_user.heartbeats.exists? || params[:show_wakatime_setup_notice]
        @show_wakatime_setup_notice = true
        if (ssp = Cache::SetupSocialProofJob.perform_now)
          @ssp_message, @ssp_users_recent, @ssp_users_size = ssp.values_at(:message, :users_recent, :users_size)
        end
      end

      render inertia: "Home/SignedIn", props: signed_in_props
    else
      # Set homepage SEO content for logged-out users only
      set_homepage_seo_content

      @usage_social_proof = Cache::UsageSocialProofJob.perform_now

      @home_stats = Cache::HomeStatsJob.perform_now

      render inertia: "Home/SignedOut", props: signed_out_props
    end
  end

  def signin
    return redirect_to root_path if current_user
    continue_param = params[:continue].presence
    render inertia: "Auth/SignIn", props: {
      hca_auth_path: hca_auth_path(continue: continue_param),
      slack_auth_path: slack_auth_path(continue: continue_param),
      email_auth_path: email_auth_path,
      sign_in_email: params[:sign_in_email].present?,
      show_dev_tool: Rails.env.development?,
      dev_magic_link: (Rails.env.development? ? session.delete(:dev_magic_link) : nil),
      csrf_token: form_authenticity_token,
      continue_param: continue_param
    }
  end

  def project_durations
    return unless current_user

    archived = params[:show_archived] == "true"
    mappings = current_user.project_repo_mappings
    @project_repo_mappings = archived ? mappings.archived.includes(:repository) : mappings.active.includes(:repository)
    archived_names = mappings.archived.pluck(:project_name)

    key = "user_#{current_user.id}_project_durations_#{params[:interval]}_v2"
    key += "_#{params[:from]}_#{params[:to]}" if params[:interval] == "custom"
    key += "_archived" if archived

    cached = Rails.cache.fetch(key, expires_in: 1.minute) do
      hb = current_user.heartbeats.filter_by_time_range(params[:interval], params[:from], params[:to])
      labels = Flipper.enabled?(:hackatime_v1_import) ? current_user.project_labels : []
      projects = hb.group(:project).duration_seconds.filter_map do |proj, dur|
        next if dur <= 0
        m = @project_repo_mappings.find { |p| p.project_name == proj }
        { project: labels.find { |p| p.project_key == proj }&.label || proj || "Unknown",
          project_key: proj, repo_url: m&.repo_url, repository: m&.repository,
          has_mapping: m.present?, duration: dur }
      end.sort_by { |p| -p[:duration] }
      { projects: projects, total_time: hb.duration_seconds }
    end

    durations = cached[:projects]
    total_time = cached[:total_time]

    durations = durations.select { |p| archived_names.include?(p[:project_key]) == archived }

    durations = durations.map do |p|
      m = @project_repo_mappings.find { |mapping| mapping.project_name == p[:project_key] }
      p.merge(repo_url: m&.repo_url, repository: m&.repository)
    end

    render partial: "project_durations", locals: { project_durations: durations, total_time: total_time, show_archived: archived }
  end

  def currently_hacking
    data = Cache::CurrentlyHackingJob.perform_now
    respond_to do |format|
      format.html { render partial: "currently_hacking", locals: data }
      format.json do
        users = data[:users].map do |u|
          proj = data[:active_projects][u.id]
          { id: u.id, username: u.display_name, slack_username: u.slack_username,
            github_username: u.github_username, display_name: u.display_name,
            avatar_url: u.avatar_url, slack_uid: u.slack_uid,
            active_project: proj && { name: proj.project_name, repo_url: proj.repo_url } }
        end
        render json: { count: users.size, users: users }
      end
    end
  end

  def currently_hacking_count
    respond_to do |format|
      format.json { render json: { count: Cache::CurrentlyHackingCountJob.perform_now[:count] } }
    end
  end

  def streak
    render partial: "streak"
  end

  def wakatime_alternative
    @page_title = "WakaTime Alternative - Free & Open Source Coding Time Tracker | Hackatime"
    @meta_description = "Looking for a WakaTime alternative? Hackatime is a free, open source coding time tracker with all features unlocked. Compare features, pricing, and see why developers are switching."
    @meta_keywords = "wakatime alternative, free time tracker, coding time tracker, open source wakatime, hackatime, developer analytics, programming stats"
    @og_title = "WakaTime Alternative - Free & Open Source | Hackatime"
    @og_description = @meta_description
    @twitter_title = @og_title
    @twitter_description = @meta_description

    render inertia: "WakatimeAlternative"
  end

  private

  def set_homepage_seo_content
    @page_title = @og_title = @twitter_title = "Hackatime - See How Much You Code"
    @meta_description = @og_description = @twitter_description = "Free and open source. Works with VS Code, JetBrains IDEs, vim, emacs, and 70+ other editors. Built and made free for teenagers by Hack Club."
    @meta_keywords = "coding time tracker, programming stats, open source time tracker, hack club coding tracker, free time tracking, code statistics, high school programming, coding analytics"
  end

  def signed_in_props
    {
      flavor_text: @flavor_text.to_s,
      trust_level_red: current_user&.trust_level == "red",
      show_wakatime_setup_notice: !!@show_wakatime_setup_notice,
      ssp_message: @ssp_message,
      ssp_users_recent: @ssp_users_recent || [],
      ssp_users_size: @ssp_users_size || @ssp_users_recent&.size || 0,
      github_uid_blank: current_user&.github_uid.blank?,
      github_auth_path: github_auth_path,
      wakatime_setup_path: my_wakatime_setup_path,
      dashboard_stats: InertiaRails.defer { dashboard_stats_payload }
    }
  end

  def dashboard_stats_payload
    {
      filterable_dashboard_data: filterable_dashboard_data,
      activity_graph: activity_graph_data,
      today_stats: today_stats_data
    }
  end

  def signed_out_props
    {
      flavor_text: @flavor_text.to_s,
      hca_auth_path: hca_auth_path,
      slack_auth_path: slack_auth_path,
      email_auth_path: email_auth_path,
      sign_in_email: params[:sign_in_email].present?,
      show_dev_tool: Rails.env.development?,
      dev_magic_link: (Rails.env.development? ? session.delete(:dev_magic_link) : nil),
      csrf_token: form_authenticity_token,
      home_stats: @home_stats || {}
    }
  end
end
