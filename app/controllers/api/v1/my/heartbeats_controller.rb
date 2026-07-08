class Api::V1::My::HeartbeatsController < ApplicationController
  include ActionView::Helpers::DateHelper
  before_action :ensure_authenticated!

  def most_recent
    scope = Clickhouse::Heartbeat.for_user(current_user).order(time: :desc, fields_hash: :desc)

    if params[:source_type].present?
      scope = scope.where(source_type: Heartbeat.source_types[params[:source_type]] || params[:source_type])
    else
      scope = scope.where.not(source_type: Heartbeat.source_types.fetch("test_entry"))
    end

    scope = scope.where("LOWER(editor) = ?", params[:editor].downcase) if params[:editor].present?

    heartbeat = scope.first

    render json: {
      has_heartbeat: heartbeat.present?,
      heartbeat: heartbeat && heartbeat_json(heartbeat),
      editor: heartbeat&.editor,
      time_ago: heartbeat.present? ? time_ago_in_words(Time.at(heartbeat.time)) + " ago" : nil
    }
  end

  def index
    start_time = params[:start_time].present? ? Time.parse(params[:start_time]) : Time.current.beginning_of_day
    end_time = params[:end_time].present? ? Time.parse(params[:end_time]) : Time.current.end_of_day

    heartbeats = Clickhouse::Heartbeat.for_user(current_user)
      .where("time >= ? AND time <= ?", start_time.to_f, end_time.to_f)
      .order(time: :asc, fields_hash: :asc)

    render json: {
      start_time: start_time, end_time: end_time,
      total_seconds: heartbeats.duration_seconds, heartbeats: heartbeats.map { |hb| heartbeat_json(hb) }
    }
  end

  private

  def heartbeat_json(heartbeat)
    heartbeat.as_json(except: %w[version]).merge(
      "source_type" => source_type_labels[heartbeat.source_type] || heartbeat.source_type
    )
  end

  def source_type_labels = @source_type_labels ||= Heartbeat.source_types.invert

  def ensure_authenticated!
    api_header = request.headers["Authorization"]
    raw_token = api_header&.split(" ")&.last
    api_token = case api_header&.split(" ")&.first
    when "Bearer" then raw_token
    when "Basic" then Base64.decode64(raw_token)
    end
    return render_unauthorized unless api_token.present?

    valid_key = ApiKey.find_by(token: api_token)
    return render_unauthorized unless valid_key.present?

    @current_user = valid_key.user
    render_unauthorized unless @current_user
  end

  def current_user = @current_user
end
