class StaticPagesController < InertiaController
  layout "inertia", only: :index
  before_action :ensure_current_user, only: %i[
    filterable_dashboard
    filterable_dashboard_content
  ]

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

      Time.use_zone(current_user.timezone) do
        h = ApplicationController.helpers
        rows = current_user.heartbeats.today
          .select(:language, :editor,
                  "COUNT(*) OVER (PARTITION BY language) as language_count",
                  "COUNT(*) OVER (PARTITION BY editor) as editor_count")
          .distinct.to_a

        lang_counts = rows
          .map { |r| [ r.language&.categorize_language, r.language_count ] }
          .reject { |l, _| l.blank? }
          .group_by(&:first).transform_values { |p| p.sum(&:last) }
          .sort_by { |_, c| -c }

        ed_counts = rows
          .map { |r| [ r.editor, r.editor_count ] }
          .reject { |e, _| e.blank? }.uniq
          .sort_by { |_, c| -c }

        @todays_languages = lang_counts.map { |l, _| h.display_language_name(l) }
        @todays_editors = ed_counts.map { |e, _| h.display_editor_name(e) }
        @todays_duration = current_user.heartbeats.today.duration_seconds
        @show_logged_time_sentence = @todays_duration > 1.minute && (@todays_languages.any? || @todays_editors.any?)
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

  def minimal_login
    @continue_param = params[:continue].presence
    render :minimal_login, layout: "doorkeeper/application"
  end

  def what_is_hackatime
    @page_title = @og_title = @twitter_title = "What is Hackatime? - Free Coding Time Tracker"
    @meta_description = @og_description = @twitter_description = "Hackatime is a free, open-source coding time tracker built by Hack Club for high school students. Track your programming time across 75+ editors and see your coding statistics."
    @meta_keywords = "what is hackatime, hackatime definition, hack club time tracker, coding time tracker, programming statistics"
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
      labels = current_user.project_labels
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

  def filterable_dashboard
    load_dashboard_data
    %i[project language operating_system editor category].each do |f|
      instance_variable_set("@selected_#{f}", params[f]&.split(",") || [])
    end
    @selected_interval = params[:interval]
    @selected_from = params[:from]
    @selected_to = params[:to]
    render partial: "filterable_dashboard"
  end

  def filterable_dashboard_content
    load_dashboard_data
    render partial: "filterable_dashboard_content"
  end

  private

  def load_dashboard_data
    filterable_dashboard_data.each { |k, v| instance_variable_set("@#{k}", v) }
  end

  def ensure_current_user
    redirect_to(root_path, alert: "You must be logged in to view this page") unless current_user
  end

  def set_homepage_seo_content
    @page_title = @og_title = @twitter_title = "Hackatime - See How Much You Code"
    @meta_description = @og_description = @twitter_description = "Free and open source. Works with VS Code, JetBrains IDEs, vim, emacs, and 70+ other editors. Built and made free for teenagers by Hack Club."
    @meta_keywords = "coding time tracker, programming stats, open source time tracker, hack club coding tracker, free time tracking, code statistics, high school programming, coding analytics"
  end

  def signed_in_props
    helpers = ApplicationController.helpers
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
      show_logged_time_sentence: !!@show_logged_time_sentence,
      todays_duration_display: helpers.short_time_detailed(@todays_duration.to_i),
      todays_languages: @todays_languages || [],
      todays_editors: @todays_editors || [],
      filterable_dashboard_data: filterable_dashboard_data,
      activity_graph: activity_graph_data
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

  def filterable_dashboard_data
    filters = %i[project language operating_system editor category]
    interval = params[:interval]
    key = [ current_user ] + filters.map { |f| params[f] } + [ interval.to_s, params[:from], params[:to] ]
    hb = current_user.heartbeats
    h = ApplicationController.helpers

    Rails.cache.fetch(key, expires_in: 5.minutes) do
      archived = current_user.project_repo_mappings.archived.pluck(:project_name)
      result = {}

      Time.use_zone(current_user.timezone) do
        filters.each do |f|
          options = current_user.heartbeats.distinct.pluck(f).compact_blank
          options = options.reject { |n| archived.include?(n) } if f == :project
          result[f] = options.map { |k|
            f == :language ? k.categorize_language : (%i[operating_system editor].include?(f) ? k.capitalize : k)
          }.uniq

          next unless params[f].present?
          arr = params[f].split(",")
          hb = if %i[operating_system editor].include?(f)
            hb.where(f => arr.flat_map { |v| [ v.downcase, v.capitalize ] }.uniq)
          elsif f == :language
            raw = current_user.heartbeats.distinct.pluck(f).compact_blank.select { |l| arr.include?(l.categorize_language) }
            raw.any? ? hb.where(f => raw) : hb
          else
            hb.where(f => arr)
          end
          result["singular_#{f}"] = arr.length == 1
        end

        hb = hb.filter_by_time_range(interval, params[:from], params[:to])
        result[:total_time] = hb.duration_seconds
        result[:total_heartbeats] = hb.count

        filters.each do |f|
          stats = hb.group(f).duration_seconds
          stats = stats.reject { |n, _| archived.include?(n) } if f == :project
          result["top_#{f}"] = stats.max_by { |_, v| v }&.first
        end

        result["top_editor"] &&= h.display_editor_name(result["top_editor"])
        result["top_operating_system"] &&= h.display_os_name(result["top_operating_system"])
        result["top_language"] &&= h.display_language_name(result["top_language"])

        unless result["singular_project"]
          result[:project_durations] = hb.group(:project).duration_seconds
            .reject { |p, _| archived.include?(p) }.sort_by { |_, d| -d }.first(10).to_h
        end

        %i[language editor operating_system category].each do |f|
          next if result["singular_#{f}"]
          stats = hb.group(f).duration_seconds.each_with_object({}) do |(raw, dur), agg|
            k = raw.to_s.presence || "Unknown"
            k = f == :language ? (k == "Unknown" ? k : k.categorize_language) : (%i[editor operating_system].include?(f) ? k.downcase : k)
            agg[k] = (agg[k] || 0) + dur
          end
          result["#{f}_stats"] = stats.sort_by { |_, d| -d }.first(10).map { |k, v|
            label = case f
            when :editor then h.display_editor_name(k)
            when :operating_system then h.display_os_name(k)
            when :language then h.display_language_name(k)
            else k
            end
            [ label, v ]
          }.to_h
        end

        result[:weekly_project_stats] = (0..11).to_h do |w|
          ws = w.weeks.ago.beginning_of_week
          [ ws.to_date.iso8601, hb.where(time: ws.to_f..w.weeks.ago.end_of_week.to_f)
              .group(:project).duration_seconds.reject { |p, _| archived.include?(p) } ]
        end
      end
      result[:selected_interval] = interval.to_s
      result[:selected_from] = params[:from].to_s
      result[:selected_to] = params[:to].to_s
      filters.each { |f| result["selected_#{f}"] = params[f]&.split(",") || [] }

      result
    end
  end

  def activity_graph_data
    tz = current_user.timezone
    key = "user_#{current_user.id}_daily_durations_#{tz}"
    durations = Rails.cache.fetch(key, expires_in: 1.minute) do
      Time.use_zone(tz) { current_user.heartbeats.daily_durations(user_timezone: tz).to_h }
    end

    {
      start_date: 365.days.ago.to_date.iso8601,
      end_date: Time.current.to_date.iso8601,
      duration_by_date: durations.transform_keys { |d| d.to_date.iso8601 }.transform_values(&:to_i),
      busiest_day_seconds: 8.hours.to_i,
      timezone_label: ActiveSupport::TimeZone[tz].to_s,
      timezone_settings_path: "/my/settings#user_timezone"
    }
  end
end
