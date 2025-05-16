class Api::Hackatime::V1::HackatimeController < ApplicationController
  before_action :set_user, except: [ :index ]
  skip_before_action :verify_authenticity_token
  before_action :set_raw_heartbeat_upload, only: [ :push_heartbeats ]

  def index
    redirect_to root_path
  end

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
      render json: { responses: handle_heartbeat(heartbeat_array) }, status: :created
    else
      # POST /api/hackatime/v1/users/:id/heartbeats
      # example response:
      # status: 202
      # {
      #   ...heartbeat_data
      # }
      heartbeat_array = Array(heartbeat_params)
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

  private

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
    params.to_unsafe_h["_json"] || {}
  end

  def handle_heartbeat(heartbeat_array)
    results = []
    heartbeat_array.each do |heartbeat|
      source_type = :direct_entry

      if heartbeat[:user_agent].present?
        parsed_ua = WakatimeService.parse_user_agent(heartbeat[:user_agent])
      elsif request.headers["User-Agent"].present?
        parsed_ua = WakatimeService.parse_user_agent(request.headers["User-Agent"])
      else
        parsed_ua = { editor: "Unknown", os: "Unknown" }
      end

      # special case: if the entity is "test.txt", this is a test heartbeat
      if heartbeat[:entity] == "test.txt"
        source_type = :test_entry
      end

      attrs = heartbeat.merge({
        user_id: @user.id,
        source_type: source_type,
        ip_address: request.remote_ip,
        editor: parsed_ua[:editor],
        operating_system: parsed_ua[:os],
        machine: request.headers["X-Machine-Name"] || "Unknown"
      })
      new_heartbeat = Heartbeat.find_or_create_by(attrs)
      if @raw_heartbeat_upload.present? && new_heartbeat.persisted?
        new_heartbeat.raw_heartbeat_upload ||= @raw_heartbeat_upload
        new_heartbeat.save! if new_heartbeat.changed?
      end
      queue_project_mapping(heartbeat[:project])
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
      :user_agent
    ]
  end

  # allow either heartbeat or heartbeats
  def heartbeat_bulk_params
    if params[:_json].present?
      { heartbeats: params.permit(_json: [ *heartbeat_keys ])[:_json] }
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
    elsif params[:hackatime].present?
      params.require(:hackatime).permit(*heartbeat_keys)
    else
      params.permit(*heartbeat_keys)
    end
  end
end
