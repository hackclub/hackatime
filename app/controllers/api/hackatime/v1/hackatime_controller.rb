class Api::Hackatime::V1::HackatimeController < ApplicationController
  before_action :set_user
  before_action :validate_user_id_parameter
  skip_before_action :verify_authenticity_token
  skip_before_action :enforce_lockout
  before_action :check_lockout, only: [ :push_heartbeats ]
  before_action :set_raw_heartbeat_upload, only: [ :push_heartbeats ], if: :is_blank?

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
      heartbeat_array = heartbeat_bulk_params[:heartbeats].map(&:to_h)

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
      heartbeat_array = Array(heartbeat_params)

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
      result = {
        data: {
          grand_total: {
            text: @user.format_extension_text(hbt.duration_seconds),
            total_seconds: hbt.duration_seconds
          }
        }
      }
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

  def is_blank?
    body = body_to_json
    body.present? && (body.is_a?(Array) ? body.any? : true)
  end

  def calculate_category_stats(heartbeats, category)
    return [] if heartbeats.empty?

    # Manual calculation approach to avoid SQL issues
    category_durations = {}

    # First, group heartbeats by category
    grouped_heartbeats = {}
    heartbeats.each do |hb|
      category_value = hb.send(category) || "unknown"
      grouped_heartbeats[category_value] ||= []
      grouped_heartbeats[category_value] << hb
    end

    # Calculate duration for each category
    grouped_heartbeats.each do |name, hbs|
      duration = 0
      hbs = hbs.sort_by(&:time)

      prev_time = nil
      hbs.each do |hb|
        current_time = hb.time
        if prev_time && (current_time - prev_time) <= 120 # 2-minute timeout
          duration += (current_time - prev_time)
        end
        prev_time = current_time
      end

      # Add a final 2 minutes for the last heartbeat if we have any
      duration += 120 if hbs.any?

      category_durations[name] = duration
    end

    # Calculate total duration for percentage calculations
    total_duration = category_durations.values.sum.to_f
    return [] if total_duration == 0

    # Format the data for each category
    category_durations.map do |name, duration|
      name = name.presence || "unknown"
      name = case category
      when "editor" then ApplicationController.helpers.display_editor_name(name)
      when "operating_system" then ApplicationController.helpers.display_os_name(name)
      when "language" then ApplicationController.helpers.display_language_name(name)
      else name
      end
      percent = ((duration / total_duration) * 100).round(2)
      hours = duration.to_i / 3600
      minutes = (duration.to_i % 3600) / 60
      seconds = duration.to_i % 60
      digital = format("%d:%02d:%02d", hours, minutes, seconds)
      text = "#{hours} hrs #{minutes} mins"

      {
        name: name,
        total_seconds: duration.to_i,
        percent: percent,
        digital: digital,
        text: text,
        hours: hours,
        minutes: minutes,
        seconds: seconds
      }
    end.sort_by { |item| -item[:total_seconds] }
  end

  def set_raw_heartbeat_upload
    @raw_heartbeat_upload = RawHeartbeatUpload.create!(
      request_headers: headers_to_json,
      request_body: body_to_json
    )
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

  def handle_heartbeat(heartbeat_array)
    results = []
    heartbeat_array.each do |heartbeat|
      source_type = :direct_entry

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

      attrs = heartbeat.merge({
        user_id: @user.id,
        source_type: source_type,
        ip_address: request.headers["CF-Connecting-IP"] || request.remote_ip,
        editor: parsed_ua[:editor],
        operating_system: parsed_ua[:os],
        machine: request.headers["X-Machine-Name"]
      })
      new_heartbeat = Heartbeat.find_or_create_by(attrs)
      if @raw_heartbeat_upload.present? && new_heartbeat.persisted?
        new_heartbeat.raw_heartbeat_upload ||= @raw_heartbeat_upload
        new_heartbeat.save! if new_heartbeat.changed?
      end
      queue_project_mapping(heartbeat[:project])
      queue_heartbeat_public_activity(@user.id, heartbeat[:project]) if new_heartbeat.persisted?
      results << [ new_heartbeat.attributes, 201 ]
    rescue => e
      Rails.logger.error("Error creating heartbeat: #{e.class.name} #{e.message}")
      results << [ { error: e.message, type: e.class.name }, 422 ]
    end
    results
  end

  def queue_project_mapping(project_name)
    # only queue the job once per hour
    Rails.cache.fetch("attempt_project_repo_mapping_job_#{@user.id}_#{project_name}", expires_in: 1.hour) do
      AttemptProjectRepoMappingJob.perform_later(@user.id, project_name)
    end
  rescue => e
    # never raise an error here because it will break the heartbeat flow
    Rails.logger.error("Error queuing project mapping: #{e.class.name} #{e.message}")
  end

  def queue_heartbeat_public_activity(user_id, project_name)
    # only queue the job once per minute
    Rails.cache.fetch("heartbeat_public_activity_#{user_id}_#{project_name}", expires_in: 30.seconds) do
      # temporarily disable
      # CreateHeartbeatActivityJob.perform_later(user_id, project_name)
    end
  rescue => e
    # never raise an error here because it will break the heartbeat flow
    Rails.logger.error("Error queuing heartbeat public activity: #{e.class.name} #{e.message}")
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

    # When using an admin key, we allow any ID for endpoints that accept an :id parameter.
    admin_key = AdminApiKey.find_by(token: api_token)
    if admin_key.present?
      @admin_api_key = admin_key
      @current_admin_user = admin_key.user
      @user = admin_key.user
      return
    end

    valid_key = ApiKey.find_by(token: api_token)
    return render json: { error: "Unauthorized" }, status: :unauthorized unless valid_key.present?

    @user = valid_key.user
    render json: { error: "Unauthorized" }, status: :unauthorized unless @user
  end

  def validate_user_id_parameter
    return unless params[:id].present?

    requested_id = params[:id] # e.g. "current", user ID, slack UID

    if @admin_api_key.present?
      if requested_id == "current"
        # When using an admin key, the caller MUST specify a user ID.
        return render json: { error: "Unauthorized" }, status: :unauthorized
      end

      target_user = User.find_by(id: requested_id) || User.find_by(slack_uid: requested_id)
      unless target_user
        return render json: { error: "User not found" }, status: :not_found
      end

      @user = target_user
    else
      # This is a regular API key - the only user they can fetch is themselves.
      if requested_id != "current"
        return render json: { error: "Unauthorized" }, status: :unauthorized
      end

      # @user is already set by set_user.
    end
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
