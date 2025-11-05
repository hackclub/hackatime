class StaticPagesController < ApplicationController
  before_action :ensure_current_user, only: %i[
    filterable_dashboard
    filterable_dashboard_content
  ]

  def index
    if current_user
      flavor_texts = FlavorText.motto + FlavorText.conditional_mottos(current_user)
      flavor_texts += FlavorText.rare_motto if Random.rand(10) < 1
      @flavor_text = flavor_texts.sample

      unless params[:date].blank?
        # implement this later– for now just redirect to the projects page with the date
        begin
          date = Date.parse(params[:date])
          redirect_to "/my/projects?interval=custom&from=#{date}&to=#{date}"
        rescue ArgumentError
        end
      end

      if current_user.heartbeats.empty? || params[:show_wakatime_setup_notice]
        @show_wakatime_setup_notice = true

        setup_social_proof = Cache::SetupSocialProofJob.perform_now
        if setup_social_proof.present?
          @ssp_message = setup_social_proof[:message]
          @ssp_users_recent = setup_social_proof[:users_recent]
          @ssp_users_size = setup_social_proof[:users_size]
        end

      end

      # Get languages and editors in a single query using window functions
      Time.use_zone(current_user.timezone) do
        results = current_user.heartbeats.today
          .select(
            :language,
            :editor,
            "COUNT(*) OVER (PARTITION BY language) as language_count",
            "COUNT(*) OVER (PARTITION BY editor) as editor_count"
          )
          .distinct
          .to_a

        # Process results to get sorted languages and editors
        language_counts = results
          .map { |r| [ r.language&.downcase, r.language_count ] }
          .reject { |lang, _| lang.nil? || lang.empty? }
          .uniq
          .sort_by { |_, count| -count }

        editor_counts = results
          .map { |r| [ r.editor, r.editor_count ] }
          .reject { |ed, _| ed.nil? || ed.empty? }
          .uniq
          .sort_by { |_, count| -count }

        @todays_languages = language_counts.map(&:first).map { |language| ApplicationController.helpers.display_language_name(language) }
        @todays_editors = editor_counts.map(&:first).map { |editor| ApplicationController.helpers.display_editor_name(editor) }
        @todays_duration = current_user.heartbeats.today.duration_seconds

        if @todays_duration > 1.minute
          @show_logged_time_sentence = @todays_languages.any? || @todays_editors.any?
        end
      end

      cached_data = filterable_dashboard_data
      cached_data.entries.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    else
      # Set homepage SEO content for logged-out users only
      set_homepage_seo_content

      @usage_social_proof = Cache::UsageSocialProofJob.perform_now

      @home_stats = Cache::HomeStatsJob.perform_now
    end
  end

  def minimal_login
    @continue_param = params[:continue] if params[:continue].present?
    render :minimal_login, layout: "doorkeeper/application"
  end

  def mini_leaderboard
    use_timezone_leaderboard = current_user&.default_timezone_leaderboard

    if use_timezone_leaderboard && current_user&.timezone_utc_offset
      # we now doing it by default wooo
      @leaderboard = LeaderboardService.get(
        period: :daily,
        date: Date.current,
        offset: current_user.timezone_utc_offset
      )

      if @leaderboard&.entries&.empty?
        Rails.logger.warn "[MiniLeaderboard] Regional leaderboard empty for offset #{current_user.timezone_utc_offset}"
        @leaderboard = nil
      end
    end

    if @leaderboard.nil?
      @leaderboard = LeaderboardService.get(
        period: :daily,
        date: Date.current
      )
    end

    @active_projects = Cache::ActiveProjectsJob.perform_now

    render partial: "leaderboards/mini_leaderboard", locals: {
      leaderboard: @leaderboard,
      current_user: current_user
    }
  end

  def project_durations
    return unless current_user

    @project_repo_mappings = current_user.project_repo_mappings.includes(:repository)
    cache_key = "user_#{current_user.id}_project_durations_#{params[:interval]}"
    cache_key += "_#{params[:from]}_#{params[:to]}" if params[:interval] == "custom"

    project_durations = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      heartbeats = current_user.heartbeats.filter_by_time_range(params[:interval], params[:from], params[:to])
      project_times = heartbeats.group(:project).duration_seconds
      project_labels = current_user.project_labels
      project_times.map do |project, duration|
        mapping = @project_repo_mappings.find { |p| p.project_name == project }
        {
          project: project_labels.find { |p| p.project_key == project }&.label || project || "Unknown",
          repo_url: mapping&.repo_url,
          repository: mapping&.repository,
          duration: duration
        }
      end.filter { |p| p[:duration].positive? }.sort_by { |p| p[:duration] }.reverse
    end
    render partial: "project_durations", locals: { project_durations: project_durations }
  end

  def activity_graph
    return unless current_user

    user_tz = current_user.timezone
    cache_key = "user_#{current_user.id}_daily_durations_#{user_tz}"

    daily_durations = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      Time.use_zone(user_tz) do
        current_user.heartbeats.daily_durations(user_timezone: user_tz).to_h
      end
    end

    # Consider 8 hours as a "full" day of coding
    length_of_busiest_day = 8.hours.to_i  # 28800 seconds

    render partial: "activity_graph", locals: {
      daily_durations: daily_durations,
      length_of_busiest_day: length_of_busiest_day
    }
  end

  def currently_hacking
    locals = Cache::CurrentlyHackingJob.perform_now

    respond_to do |format|
      format.html { render partial: "currently_hacking", locals: locals }
      format.json do
        json_response = locals[:users].map do |user|
          {
            id: user.id,
            username: user.display_name,
            slack_username: user.slack_username,
            github_username: user.github_username,
            display_name: user.display_name,
            avatar_url: user.avatar_url,
            slack_uid: user.slack_uid,
            active_project: locals[:active_projects][user.id]&.then do |project|
              {
                name: project.project_name,
                repo_url: project.repo_url
              }
            end
          }
        end

        render json: {
          count: locals[:users].count,
          users: json_response
        }
      end
    end
  end

  def currently_hacking_count
    result = Cache::CurrentlyHackingCountJob.perform_now

    respond_to do |format|
      format.json { render json: { count: result[:count] } }
    end
  end

  def streak
    render partial: "streak"
  end

  def filterable_dashboard
    cached_data = filterable_dashboard_data
    cached_data.entries.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    render partial: "filterable_dashboard"
  end

  def filterable_dashboard_content
    cached_data = filterable_dashboard_data
    cached_data.entries.each do |key, value|
      instance_variable_set("@#{key}", value)
    end

    render partial: "filterable_dashboard_content"
  end

  private

  def ensure_current_user
    redirect_to root_path, alert: "You must be logged in to view this page" unless current_user
  end

  def set_homepage_seo_content
    title = "Hackatime - See How Much You Code"
    desc = "Free and open source. Works with VS Code, JetBrains IDEs, vim, emacs, and 70+ other editors. Built and made free for teenagers by Hack Club."

    @page_title = title
    @meta_description = desc
    @meta_keywords = "coding time tracker, programming stats, wakatime alternative, free time tracking, code statistics, high school programming, coding analytics"
    @og_title = title
    @og_description = desc
    @twitter_title = title
    @twitter_description = desc
  end

  def filterable_dashboard_data
    filters = %i[project language operating_system editor category]

    # Cache key based on user and filter parameters
    cache_key = []
    cache_key << current_user
    filters.each do |filter|
      cache_key << params[filter]
    end

  def dashboard
    @project          = Project.distinct.pluck(:name)
    @language         = Language.distinct.pluck(:name)
    @operating_system = OperatingSystem.distinct.pluck(:name)
    @editor           = Editor.distinct.pluck(:name)
    @category         = Category.distinct.pluck(:name)

    # Parse filter selections from params for initial load and deep-linking
    @selected_project          = params[:project]&.split(',') || []
    @selected_language         = params[:language]&.split(',') || []
    @selected_operating_system = params[:operating_system]&.split(',') || []
    @selected_editor           = params[:editor]&.split(',') || []
    @selected_category         = params[:category]&.split(',') || []
  end

    filtered_heartbeats = current_user.heartbeats
    # Load filter options and apply filters with caching
    Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      result = {}
      # Load filter options
      Time.use_zone(current_user.timezone) do
        filters.each do |filter|
          group_by_time = current_user.heartbeats.group(filter).duration_seconds
          result[filter] = group_by_time.sort_by { |k, v| v }
                                        .reverse.map(&:first)
                                        .compact_blank
                                        .map { |k| 
                                          if filter == :editor
                                            ApplicationController.helpers.display_editor_name(k)
                                          elsif filter == :operating_system
                                            ApplicationController.helpers.display_os_name(k)
                                          elsif filter == :language
                                            ApplicationController.helpers.display_language_name(k)
                                          else
                                            k
                                          end
                                        }
                                        .uniq

          if params[filter].present?
            filter_arr = params[filter].split(",")
            if %i[operating_system editor].include?(filter)
              # search for both lowercase and capitalized versions
              normalized_arr = filter_arr.flat_map { |v| [ v.downcase, v.capitalize ] }.uniq
              filtered_heartbeats = filtered_heartbeats.where(filter => normalized_arr)
            else
              filtered_heartbeats = filtered_heartbeats.where(filter => filter_arr)
            end


            result["singular_#{filter}"] = filter_arr.length == 1
          end
        end

        # Only use the concern for time filtering
        filtered_heartbeats = filtered_heartbeats.filter_by_time_range(params[:interval], params[:from], params[:to])

        result[:filtered_heartbeats] = filtered_heartbeats

        # Calculate stats for filtered data
        result[:total_time] = filtered_heartbeats.duration_seconds
        result[:total_heartbeats] = filtered_heartbeats.count

        filters.each do |filter|
          result["top_#{filter}"] = filtered_heartbeats.group(filter)
                                                       .duration_seconds
                                                       .max_by { |_, v| v }
                                                       &.first
        end

        # Transform top editor, OS, and language names
        result["top_editor"] = ApplicationController.helpers.display_editor_name(result["top_editor"]) if result["top_editor"]
        result["top_operating_system"] = ApplicationController.helpers.display_os_name(result["top_operating_system"]) if result["top_operating_system"]
        result["top_language"] = ApplicationController.helpers.display_language_name(result["top_language"]) if result["top_language"]

        # Prepare project durations data
        result[:project_durations] = filtered_heartbeats
          .group(:project)
          .duration_seconds
          .sort_by { |_, duration| -duration }
          .first(10)
          .to_h unless result["singular_project"]

        # Prepare pie chart data
        %i[language editor operating_system category].each do |filter|
          # If the filter is editor or operating_system, normalize and sum the durations
          stats = filtered_heartbeats
            .group(filter)
            .duration_seconds
            .each_with_object({}) do |(raw_key, duration), agg|
              key = raw_key.to_s.presence || "Unknown"
              key = key.downcase if %i[editor operating_system].include?(filter)
              agg[key] = (agg[key] || 0) + duration
            end

          result["#{filter}_stats"] =
            stats
              .sort_by { |_, duration| -duration }
              .first(10)
              .map { |k, v|
                label = case filter
                  when :editor then ApplicationController.helpers.display_editor_name(k)
                  when :operating_system then ApplicationController.helpers.display_os_name(k)
                  when :language then ApplicationController.helpers.display_language_name(k)
                  when :category then k
                  else k.capitalize
                end
                [ label, v ]
              }
              .to_h unless result["singular_#{filter}"]
        end
        # result[:language_stats] = filtered_heartbeats
        #   .group(:language)
        #   .duration_seconds
        #   .sort_by { |_, duration| -duration }
        #   .first(10)
        #   .map { |k, v| [ k.presence || "Unknown", v ] }
        #   .to_h unless result["singular_language"]

        # result[:editor_stats] = filtered_heartbeats
        #   .group(:editor)
        #   .duration_seconds
        #   .sort_by { |_, duration| -duration }
        #   .map { |k, v| [ k.presence || "Unknown", v ] }
        #   .to_h unless result["singular_editor"]

        # result[:operating_system_stats] = filtered_heartbeats
        #   .group(:operating_system)
        #   .duration_seconds
        #   .sort_by { |_, duration| -duration }
        #   .map { |k, v| [ k.presence || "Unknown", v ] }
        #   .to_h unless result["singular_operating_system"]

        # result[:category_stats] = filtered_heartbeats
        #   .group(:category)
        #   .duration_seconds
        #   .sort_by { |_, duration| -duration }
        #   .map { |k, v| [ k.presence || "Unknown", v ] }
        #   .to_h unless result["singular_category"]

        # Calculate weekly project stats for the last 6 months
        result[:weekly_project_stats] = {}
        (0..25).each do |week_offset|  # 26 weeks = 6 months
          week_start = week_offset.weeks.ago.beginning_of_week
          week_end = week_offset.weeks.ago.end_of_week

          week_stats = filtered_heartbeats
            .where(time: week_start.to_f..week_end.to_f)
            .group(:project)
            .duration_seconds

          result[:weekly_project_stats][week_start.to_date.iso8601] = week_stats
        end
      end

      result
    end
  end
end
