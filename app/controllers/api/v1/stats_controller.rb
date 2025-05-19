class Api::V1::StatsController < ApplicationController
  before_action :ensure_authenticated!, only: [ :show ], unless: -> { Rails.env.development? }
  before_action :set_user, only: [ :user_stats, :user_spans ]

  def show
    # take either user_id with a start date & end date
    start_date = Date.parse(params[:start_date]).beginning_of_day if params[:start_date].present?
    start_date ||= 10.years.ago
    end_date = Date.parse(params[:end_date]).end_of_day if params[:end_date].present?
    end_date ||= Date.today.end_of_day

    query = Heartbeat.where(time: start_date..end_date)
    if params[:username].present?
      user_id = params[:username]

      return render json: { error: "User not found" }, status: :not_found unless user_id.present?

      query = query.where(user_id: user_id)
    end

    if params[:user_email].present?
      user_id = EmailAddress.find_by(email: params[:user_email])&.user_id || find_by_email(params[:user_email])

      return render json: { error: "User not found" }, status: :not_found unless user_id.present?

      query = query.where(user_id: user_id)
    end

    render plain: query.duration_seconds
  end

  def user_stats
    # Used by the github stats page feature

    return render plain: "User not found", status: :not_found unless @user.present?

    start_date = params[:start_date].to_datetime if params[:start_date].present?
    start_date ||= 10.years.ago
    end_date = params[:end_date].to_datetime if params[:end_date].present?
    end_date ||= Date.today.end_of_day

    limit = params[:limit].to_i

    enabled_features = params[:features]&.split(",")&.map(&:to_sym)
    enabled_features ||= %i[languages]

    summary = WakatimeService.new(
      user: @user,
      specific_filters: enabled_features,
      allow_cache: false,
      limit: limit,
      start_date: start_date,
      end_date: end_date
    ).generate_summary

    render json: { data: summary }
  end

  def user_spans
    return render json: { error: "User not found" }, status: :not_found unless @user

    start_date = Date.parse(params[:start_date]) if params[:start_date].present?
    start_date ||= 10.years.ago
    end_date = Date.parse(params[:end_date]) if params[:end_date].present?
    end_date ||= Date.today

    timespan = (start_date.beginning_of_day.to_f..end_date.end_of_day.to_f)

    heartbeats = @user.heartbeats
                      .where(time: timespan)

    if params[:project].present?
      heartbeats = heartbeats.where(project: params[:project])
    end

    render json: { spans: heartbeats.to_span }
  end

  private

  def set_user
    token = request.headers["Authorization"]&.split(" ")&.last
    username = params[:username]

    @user = begin
      if username == "my" && token.present?
        ApiKey.find_by(token: token)&.user
      else
        User.where(id: username).or(User.where(slack_uid: username)).first
      end
    end
  end

  def ensure_authenticated!
    token = request.headers["Authorization"]&.split(" ")&.last
    token ||= params[:api_key]

    render plain: "Unauthorized", status: :unauthorized unless token == ENV["STATS_API_KEY"]
  end

  def find_by_email(email)
    cache_key = "user_id_by_email/#{email}"
    slack_id = Rails.cache.fetch(cache_key, expires_in: 1.week) do
      response = HTTP
        .auth("Bearer #{ENV["SLACK_USER_OAUTH_TOKEN"]}")
        .get("https://slack.com/api/users.lookupByEmail", params: { email: email })

      JSON.parse(response.body)["user"]["id"]
    rescue => e
      Rails.logger.error("Error finding user by email: #{e}")
      nil
    end

    Rails.cache.delete(cache_key) if slack_id.nil?

    slack_id
  end
end
