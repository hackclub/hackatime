class Api::V1::My::HeartbeatsController < ApplicationController
  include ActionView::Helpers::DateHelper
  before_action :ensure_authenticated!

  def most_recent
    scope = current_user.heartbeats.order(time: :desc)

    if params[:editor].present?
      scope = scope.where("LOWER(editor) = ?", params[:editor].downcase)
    end

    heartbeat = scope.first

    render json: {
      has_heartbeat: heartbeat.present?,
      heartbeat: heartbeat,
      time_ago: heartbeat.present? ? time_ago_in_words(Time.at(heartbeat.time)) + " ago" : nil
    }
  end

  def index
    start_time = params[:start_time].present? ? Time.parse(params[:start_time]) : Time.current.beginning_of_day
    end_time = params[:end_time].present? ? Time.parse(params[:end_time]) : Time.current.end_of_day

    heartbeats = current_user.heartbeats
      .where("time >= ? AND time <= ?", start_time.to_f, end_time.to_f)
      .order(time: :asc)

    render json: {
      start_time: start_time,
      end_time: end_time,
      total_seconds: heartbeats.duration_seconds,
      heartbeats: heartbeats
    }
  end

  private

  def ensure_authenticated!
    api_header = request.headers["Authorization"]
    raw_token = api_header&.split(" ")&.last
    header_type = api_header&.split(" ")&.first
    if header_type == "Bearer"
      api_token = raw_token
    elsif header_type == "Basic"
      api_token = Base64.decode64(raw_token)
    end
    return render json: { error: "Unauthorized" }, status: :unauthorized unless api_token.present?

    valid_key = ApiKey.find_by(token: api_token)
    return render json: { error: "Unauthorized" }, status: :unauthorized unless valid_key.present?

    @current_user = valid_key.user
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end
end
