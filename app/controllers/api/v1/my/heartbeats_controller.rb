class Api::V1::My::HeartbeatsController < ApplicationController
  include ActionView::Helpers::DateHelper
  include DateParsing

  before_action :ensure_authenticated!

  def most_recent
    scope = current_user.heartbeats.order(time: :desc)

    if params[:source_type].present?
      scope = scope.where(source_type: params[:source_type])
    else
      scope = scope.where.not(source_type: :test_entry)
    end

    scope = scope.where("LOWER(editor) = ?", params[:editor].downcase) if params[:editor].present?

    heartbeat = scope.first

    render json: {
      has_heartbeat: heartbeat.present?,
      heartbeat: heartbeat,
      editor: heartbeat&.editor,
      time_ago: heartbeat.present? ? time_ago_in_words(Time.at(heartbeat.time)) + " ago" : nil
    }
  end

  def index
    time_range = parse_date_range(
      start_value: params[:start_time],
      end_value: params[:end_time],
      start_default: Time.current.beginning_of_day,
      end_default: Time.current.end_of_day
    ) { |value| Time.parse(value) }
    return unless time_range

    start_time = time_range.begin
    end_time = time_range.end

    heartbeats = current_user.heartbeats
      .where("time >= ? AND time <= ?", start_time.to_f, end_time.to_f)
      .order(time: :asc)

    render json: {
      start_time: start_time, end_time: end_time,
      total_seconds: heartbeats.duration_seconds, heartbeats: heartbeats
    }
  end

  private

  def ensure_authenticated!
    @current_user = api_user_from_credentials(
      oauth_scopes: [ "read" ],
      api_key_sources: %i[bearer basic]
    )
    render_unauthorized unless @current_user
  end

  def current_user = @current_user
end
