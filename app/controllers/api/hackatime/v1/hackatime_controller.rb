class Api::Hackatime::V1::HackatimeController < ApplicationController
  before_action :set_user
  skip_before_action :verify_authenticity_token
  skip_before_action :enforce_lockout
  before_action :check_lockout, only: [ :push_heartbeats ]

  HEARTBEAT_KEYS = %i[
    branch category created_at cursorpos dependencies editor entity is_write
    language line_additions line_deletions lineno lines machine operating_system
    project project_root_count time type user_agent plugin
  ].freeze

  MAX_BULK_HEARTBEATS = 100

  def push_heartbeats
    if params["format"] == "bulk"
      # POST /api/hackatime/v1/users/:id/heartbeats.bulk
      heartbeat_array = heartbeat_bulk_params[:heartbeats]
      return render_bad_request("No data provided...") if heartbeat_array.empty?
      if heartbeat_array.size > MAX_BULK_HEARTBEATS
        return render_bad_request("Too many heartbeats in a single request (max #{MAX_BULK_HEARTBEATS})")
      end

      render json: { responses: handle_heartbeat(heartbeat_array) }, status: :created
    else
      # POST /api/hackatime/v1/users/:id/heartbeats
      heartbeat_array = Array.wrap(heartbeat_params)
      return render_bad_request("No data provided...") if heartbeat_array.empty? || heartbeat_params.blank?

      new_heartbeat = handle_heartbeat(heartbeat_array)&.first&.first
      render json: new_heartbeat, status: :accepted
    end
  end

  def status_bar_today
    Time.use_zone(@user.timezone) do
      total_seconds = @user.heartbeats.today.duration_seconds
      result = {
        data: {
          grand_total: {
            text: @user.format_extension_text(total_seconds),
            total_seconds: total_seconds
          }
        }
      }

      daily_goal = @user.goals.find_by(period: "day")
      if daily_goal && (goal_progress = ProgrammingGoalsProgressService.new(user: @user, goals: [ daily_goal ]).call.first)
        # Only append the goal text for users with simple_text style AND show_goals_in_statusbar enabled.
        if @user.simple_text? && @user.show_goals_in_statusbar
          goal_text = ApplicationController.helpers.short_time_simple(daily_goal.target_seconds)
          result[:data][:grand_total][:text] = "#{result[:data][:grand_total][:text]} / #{goal_text} goal"
        end

        result[:data][:goal] = {
          target_seconds: daily_goal.target_seconds,
          tracked_seconds: goal_progress[:tracked_seconds],
          completion_percent: goal_progress[:completion_percent],
          complete: goal_progress[:complete]
        }
      end

      render json: result
    end
  end

  def stats_last_7_days
    Time.use_zone(@user.timezone) do
      start_time = (Time.current - 7.days).beginning_of_day
      end_time = Time.current.end_of_day

      heartbeats = @user.heartbeats.where(time: start_time.to_i..end_time.to_i)
      total_seconds = heartbeats.duration_seconds.to_i
      days_covered = heartbeats.pluck(:time).map { |ts| Time.at(ts).in_time_zone(@user.timezone).to_date }.uniq.length
      daily_average = days_covered > 0 ? (total_seconds.to_f / days_covered).round(1) : 0
      human_readable_total = format_hr(total_seconds)

      hours, minutes, seconds = hms(total_seconds)
      categories = [ {
        name: "coding",
        total_seconds: total_seconds,
        percent: 100.0,
        digital: format("%d:%02d:%02d", hours, minutes, seconds),
        text: human_readable_total,
        hours: hours,
        minutes: minutes,
        seconds: seconds
      } ]

      render json: {
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
          human_readable_daily_average: format_hr(daily_average.to_i),
          is_coding_activity_visible: true,
          is_other_usage_visible: true,
          editors: calculate_category_stats(heartbeats, "editor"),
          languages: calculate_category_stats(heartbeats, "language"),
          machines: calculate_category_stats(heartbeats, "machine"),
          projects: calculate_category_stats(heartbeats, "project"),
          operating_systems: calculate_category_stats(heartbeats, "operating_system"),
          categories: categories
        }
      }
    end
  end

  private

  def hms(total) = [ total / 3600, (total % 3600) / 60, total % 60 ]

  def format_hr(total)
    h, m, _ = hms(total)
    "#{h} hrs #{m} mins"
  end

  def calculate_category_stats(heartbeats, category)
    durations = heartbeats.group(category).duration_seconds
    total_duration = durations.values.sum.to_f
    return [] if total_duration == 0

    h = ApplicationController.helpers
    durations.filter_map do |name, duration|
      next if duration <= 0
      display_name = name.presence || "unknown"
      display_name = case category
      when "editor" then h.display_editor_name(display_name)
      when "operating_system" then h.display_os_name(display_name)
      when "language" then h.display_language_name(display_name)
      else display_name
      end

      hours, minutes, seconds = hms(duration)
      {
        name: display_name,
        total_seconds: duration,
        percent: ((duration / total_duration) * 100).round(2),
        digital: format("%d:%02d:%02d", hours, minutes, seconds),
        text: "#{hours} hrs #{minutes} mins",
        hours: hours,
        minutes: minutes,
        seconds: seconds
      }
    end.sort_by { |item| -item[:total_seconds] }
  end

  def handle_heartbeat(heartbeat_array)
    result = HeartbeatIngest.call(
      user: @user,
      mode: :direct,
      heartbeats: heartbeat_array,
      request_context: {
        ip_address: request.headers["CF-Connecting-IP"] || request.remote_ip,
        machine: request.headers["X-Machine-Name"]
      }
    )

    result.items.map do |item|
      next [ item.heartbeat.attributes, 201 ] if item.status == :accepted
      error = item.error
      report_error(
        error,
        message: "Error creating heartbeat: #{error.class}: #{error.message}",
        extra: { backtrace: error.backtrace&.first(20) }
      )
      [ { error: error.message, type: error.class.name }, 422 ]
    end
  end

  def check_lockout = (render_forbidden("Account pending deletion") if @user&.pending_deletion?)

  def set_user
    api_header = request.headers["Authorization"]
    raw_token = api_header&.split(" ")&.last
    api_token = case api_header&.split(" ")&.first
    when "Bearer" then raw_token
    when "Basic" then Base64.decode64(raw_token)
    end
    api_token ||= params[:api_key] if params[:api_key].present?
    return render_unauthorized unless api_token.present?

    # Sanitize api_token to handle invalid UTF-8 sequences
    api_token = api_token.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

    valid_key = ApiKey.find_by(token: api_token)
    return render_unauthorized unless valid_key.present?

    @user = valid_key.user
    render_unauthorized unless @user
  end

  # allow either heartbeat or heartbeats
  def heartbeat_bulk_params
    if params[:_json].present?
      { heartbeats: params.permit(_json: [ *HEARTBEAT_KEYS ])[:_json] }
    elsif request.content_type&.include?("text/plain") && request.raw_post.present?
      parsed_json = JSON.parse(request.raw_post, symbolize_names: true) rescue []
      { heartbeats: parsed_json.map { |hb| hb.slice(*HEARTBEAT_KEYS) } }
    else
      params.require(:hackatime).permit(heartbeats: [ *HEARTBEAT_KEYS ])
    end
  end

  def heartbeat_params
    if params[:_json].present?
      params[:_json].first.permit(*HEARTBEAT_KEYS)
    elsif request.content_type&.include?("text/plain") && request.raw_post.present?
      parsed = JSON.parse(request.raw_post, symbolize_names: true) rescue {}
      parsed = [ parsed ] unless parsed.is_a?(Array)
      parsed.first&.with_indifferent_access&.slice(*HEARTBEAT_KEYS) || {}
    elsif params[:hackatime].present?
      params.require(:hackatime).permit(*HEARTBEAT_KEYS)
    else
      params.permit(*HEARTBEAT_KEYS)
    end
  end
end
