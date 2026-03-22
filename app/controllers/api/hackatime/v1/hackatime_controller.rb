class Api::Hackatime::V1::HackatimeController < ApplicationController
  before_action :set_user
  skip_before_action :verify_authenticity_token
  skip_before_action :enforce_lockout
  before_action :check_lockout, only: [ :push_heartbeats ]

  def push_heartbeats
    # Handle both single and bulk heartbeats based on format
    if params["format"] == "bulk"
      # POST /api/hackatime/v1/users/:id/heartbeats.bulk
      # example response:
      # status: 201
      # {
      #   "responses": [
      #     [{...heartbeat_data}, 201],
      #     [{...heartbeat_data}, 201],
      #     [{...heartbeat_data}, 201]
      #   ]
      # }
      heartbeat_array = heartbeat_bulk_params[:heartbeats]

      if heartbeat_array.empty?
        return render json: { error: "No data provided..." }, status: :bad_request
      end

      render json: { responses: handle_heartbeat(heartbeat_array) }, status: :created
    else
      # POST /api/hackatime/v1/users/:id/heartbeats
      # example response:
      # status: 202
      # {
      #   ...heartbeat_data
      # }
      heartbeat_array = Array.wrap(heartbeat_params)

      if heartbeat_array.empty? || heartbeat_params.blank?
        return render json: { error: "No data provided..." }, status: :bad_request
      end

      new_heartbeat = handle_heartbeat(heartbeat_array)&.first&.first
      render json: new_heartbeat, status: :accepted
    end
  end

  def status_bar_today
    Time.use_zone(@user.timezone) do
      hbt = @user.heartbeats.today
      total_seconds = hbt.duration_seconds

      # Check if user has a daily goal
      daily_goal = @user.goals.find_by(period: "day")

      result = {
        data: {
          grand_total: {
            text: @user.format_extension_text(total_seconds),
            total_seconds: total_seconds
          }
        }
      }

      # Include goal information if daily goal exists
      if daily_goal
        goal_progress = ProgrammingGoalsProgressService.new(user: @user, goals: [ daily_goal ]).call.first

        if goal_progress
          # Append goal progress to the user's preferred text format
          user_text = result[:data][:grand_total][:text]
          goal_text = ApplicationController.helpers.short_time_simple(daily_goal.target_seconds)

          result[:data][:grand_total][:text] = "#{user_text} / #{goal_text} today"
          result[:data][:goal] = {
            target_seconds: daily_goal.target_seconds,
            tracked_seconds: goal_progress[:tracked_seconds],
            completion_percent: goal_progress[:completion_percent],
            complete: goal_progress[:complete]
          }
        end
      end

      render json: result
    end
  end

  def stats_last_7_days
      Time.use_zone(@user.timezone) do
        # Calculate time range within the user's timezone
        start_time = (Time.current - 7.days).beginning_of_day
        end_time = Time.current.end_of_day

        # Convert to Unix timestamps
        start_timestamp = start_time.to_i
        end_timestamp = end_time.to_i

        # Get heartbeats in the time range
        heartbeats = @user.heartbeats.where(time: start_timestamp..end_timestamp)

        # Calculate total seconds
        total_seconds = heartbeats.duration_seconds.to_i

        # Get unique days
        days = []
        heartbeats.pluck(:time).each do |timestamp|
          day = Time.at(timestamp).in_time_zone(@user.timezone).to_date
          days << day unless days.include?(day)
        end
        days_covered = days.length

        # Calculate daily average
        daily_average = days_covered > 0 ? (total_seconds.to_f / days_covered).round(1) : 0

        # Format human readable strings
        hours = total_seconds / 3600
        minutes = (total_seconds % 3600) / 60
        human_readable_total = "#{hours} hrs #{minutes} mins"

        avg_hours = daily_average.to_i / 3600
        avg_minutes = (daily_average.to_i % 3600) / 60
        human_readable_daily_average = "#{avg_hours} hrs #{avg_minutes} mins"

        # Calculate statistics for different categories
        editors_data = calculate_category_stats(heartbeats, "editor")
        languages_data = calculate_category_stats(heartbeats, "language")
        projects_data = calculate_category_stats(heartbeats, "project")
        machines_data = calculate_category_stats(heartbeats, "machine")
        os_data = calculate_category_stats(heartbeats, "operating_system")

      # Categories data
      hours = total_seconds / 3600
      minutes = (total_seconds % 3600) / 60
      seconds = total_seconds % 60

      categories = [
        {
          name: "coding",
          total_seconds: total_seconds,
          percent: 100.0,
          digital: format("%d:%02d:%02d", hours, minutes, seconds),
          text: human_readable_total,
          hours: hours,
          minutes: minutes,
          seconds: seconds
        }
      ]

      result = {
        data: {
          username: @user.slack_uid,
          user_id: @user.slack_uid,
          start: start_time.iso8601,
          end: end_time.iso8601,
          status: "ok",
          total_seconds: total_seconds,
          daily_average: daily_average,
          days_including_holidays: days_covered,
          range: "last_7_days",
          human_readable_range: "Last 7 Days",
          human_readable_total: human_readable_total,
          human_readable_daily_average: human_readable_daily_average,
          is_coding_activity_visible: true,
          is_other_usage_visible: true,
          editors: editors_data,
          languages: languages_data,
          machines: machines_data,
          projects: projects_data,
          operating_systems: os_data,
          categories: categories
        }
      }

      render json: result
    end
  end

  private

  def calculate_category_stats(heartbeats, category)
    durations = heartbeats.group(category).duration_seconds

    total_duration = durations.values.sum.to_f
    return [] if total_duration == 0

    h = ApplicationController.helpers
    durations.filter_map do |name, duration|
      next if duration <= 0

      display_name = (name.presence || "unknown")
      display_name = case category
      when "editor" then h.display_editor_name(display_name)
      when "operating_system" then h.display_os_name(display_name)
      when "language" then h.display_language_name(display_name)
      else display_name
      end

      percent = ((duration / total_duration) * 100).round(2)
      hours = duration / 3600
      minutes = (duration % 3600) / 60
      seconds = duration % 60

      {
        name: display_name,
        total_seconds: duration,
        percent: percent,
        digital: format("%d:%02d:%02d", hours, minutes, seconds),
        text: "#{hours} hrs #{minutes} mins",
        hours: hours,
        minutes: minutes,
        seconds: seconds
      }
    end.sort_by { |item| -item[:total_seconds] }
  end

  def headers_to_json
    request.headers
           .env
           .select { |key| key.to_s.starts_with?("HTTP_") }
           .map { |key, value| [ key.sub(/^HTTP_/, ""), value ] }
           .to_h.to_json
  end

  def body_to_json
    return params.to_unsafe_h["_json"] if params.to_unsafe_h["_json"].present?

    # Handle text/plain content-type by manually parsing JSON body
    begin
      JSON.parse(request.raw_post) if request.raw_post.present?
    rescue JSON::ParserError
      {}
    end || {}
  end

  LAST_LANGUAGE_SENTINEL = "<<LAST_LANGUAGE>>"

  def handle_heartbeat(heartbeat_array)
    results = []
    last_language = nil
    heartbeat_array.each do |heartbeat|
      heartbeat = heartbeat.to_h.with_indifferent_access
      source_type = :direct_entry

      # Resolve <<LAST_LANGUAGE>> sentinel to the most recently used language.
      # Check within the current batch first, then fall back to the DB.
      if heartbeat[:language] == LAST_LANGUAGE_SENTINEL
        heartbeat[:language] = last_language || @user.heartbeats
          .where.not(language: [ nil, "", LAST_LANGUAGE_SENTINEL ])
          .order(time: :desc)
          .pick(:language)
      end

      # Track the last known language for subsequent heartbeats in this batch.
      last_language = heartbeat[:language] if heartbeat[:language].present?

      # Fallback to :plugin if :user_agent is not set
      fallback_value = heartbeat.delete(:plugin)
      heartbeat[:user_agent] ||= fallback_value

      parsed_ua = WakatimeService.parse_user_agent(heartbeat[:user_agent])

      # if category is not set, just default to coding
      heartbeat[:category] ||= "coding"

      # special case: if the entity is "test.txt", this is a test heartbeat
      if heartbeat[:entity] == "test.txt"
        source_type = :test_entry
      end

      heartbeat[:project] = heartbeat[:project]&.gsub(/[[:cntrl:]]/, "")&.strip

      attrs = heartbeat.merge({
        user_id: @user.id,
        source_type: source_type,
        ip_address: request.headers["CF-Connecting-IP"] || request.remote_ip,
        editor: parsed_ua[:editor],
        operating_system: parsed_ua[:os],
        machine: request.headers["X-Machine-Name"]
      })
      new_heartbeat = Heartbeat.find_or_create_by(attrs)

      queue_project_mapping(heartbeat[:project])
      results << [ new_heartbeat.attributes, 201 ]
    rescue => e
      report_error(e, message: "Error creating heartbeat")
      results << [ { error: e.message, type: e.class.name }, 422 ]
    end

    PosthogService.capture_once_per_day(@user, "heartbeat_sent", { heartbeat_count: heartbeat_array.size })
    results
  end

  def queue_project_mapping(project_name)
    # only queue the job once per hour
    Rails.cache.fetch("attempt_project_repo_mapping_job_#{@user.id}_#{project_name}", expires_in: 1.hour) do
      AttemptProjectRepoMappingJob.perform_later(@user.id, project_name)
    end
  rescue => e
    # never raise an error here because it will break the heartbeat flow
    report_error(e, message: "Error queuing project mapping")
  end

  def check_lockout
    return unless @user&.pending_deletion?
    render json: { error: "Account pending deletion" }, status: :forbidden
  end

  def set_user
    api_header = request.headers["Authorization"]
    raw_token = api_header&.split(" ")&.last
    header_type = api_header&.split(" ")&.first
    if header_type == "Bearer"
      api_token = raw_token
    elsif header_type == "Basic"
      api_token = Base64.decode64(raw_token)
    end
    if params[:api_key].present?
      api_token ||= params[:api_key]
    end
    return render json: { error: "Unauthorized" }, status: :unauthorized unless api_token.present?

    # Sanitize api_token to handle invalid UTF-8 sequences
    api_token = api_token.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

    valid_key = ApiKey.find_by(token: api_token)
    return render json: { error: "Unauthorized" }, status: :unauthorized unless valid_key.present?

    @user = valid_key.user
    render json: { error: "Unauthorized" }, status: :unauthorized unless @user
  end

  def heartbeat_keys
    [
      :branch,
      :category,
      :created_at,
      :cursorpos,
      :dependencies,
      :editor,
      :entity,
      :is_write,
      :language,
      :line_additions,
      :line_deletions,
      :lineno,
      :lines,
      :machine,
      :operating_system,
      :project,
      :project_root_count,
      :time,
      :type,
      :user_agent,
      :plugin
    ]
  end

  # allow either heartbeat or heartbeats
  def heartbeat_bulk_params
    if params[:_json].present?
      { heartbeats: params.permit(_json: [ *heartbeat_keys ])[:_json] }
    elsif request.content_type&.include?("text/plain") && request.raw_post.present?
      # Handle text/plain requests by parsing JSON directly
      parsed_json = JSON.parse(request.raw_post, symbolize_names: true) rescue []
      filtered_json = parsed_json.map { |hb| hb.slice(*heartbeat_keys) }
      { heartbeats: filtered_json }
    else
      params.require(:hackatime).permit(
        heartbeats: [
          *heartbeat_keys
        ]
      )
    end
  end

  def heartbeat_params
    # Handle both direct params and _json format from WakaTime
    if params[:_json].present?
      params[:_json].first.permit(*heartbeat_keys)
    elsif request.content_type&.include?("text/plain") && request.raw_post.present?
      # Handle text/plain requests by parsing JSON directly
      parsed_json = JSON.parse(request.raw_post, symbolize_names: true) rescue {}
      parsed_json = [ parsed_json ] unless parsed_json.is_a?(Array)
      parsed_json.first&.with_indifferent_access&.slice(*heartbeat_keys) || {}
    elsif params[:hackatime].present?
      params.require(:hackatime).permit(*heartbeat_keys)
    else
      params.permit(*heartbeat_keys)
    end
  end
end
