class Api::V1::StatsController < ApplicationController
  before_action :ensure_authenticated!, only: [ :show ], unless: -> { Rails.env.development? }
  before_action :set_user, only: [ :user_stats, :user_spans, :trust_factor, :user_projects, :user_project ]

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

    return render json: { error: "User not found" }, status: :not_found unless @user.present?

    start_date = params[:start_date].to_datetime if params[:start_date].present?
    start_date ||= 10.years.ago
    end_date = params[:end_date].to_datetime if params[:end_date].present?
    end_date ||= Date.today.end_of_day

    # /api/v1/users/current/stats?filter_by_project=harbor,high-seas
    scope = nil
    if params[:filter_by_project].present?
      filter_by_project = params[:filter_by_project].split(",")
      scope = Heartbeat.where(project: filter_by_project)
    end

    limit = params[:limit].to_i

    enabled_features = params[:features]&.split(",")&.map(&:to_sym)
    enabled_features ||= %i[languages]

    service_params = {}
    service_params[:user] = @user
    service_params[:specific_filters] = enabled_features
    service_params[:allow_cache] = false
    service_params[:limit] = limit
    service_params[:start_date] = start_date
    service_params[:end_date] = end_date
    service_params[:scope] = scope if scope.present?

    summary = WakatimeService.new(**service_params).generate_summary

    trust_level = @user.trust_level
    trust_level = "blue" if trust_level == "yellow"
    trust_value = User.trust_levels[trust_level]
    trust_info = {
      trust_level: trust_level,
      trust_value: trust_value
    }

    render json: {
      data: summary,
      trust_factor: trust_info
    }
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

  def trust_factor
    return render json: { error: "User not found" }, status: :not_found unless @user

    trust_level = @user.trust_level
    trust_level = "blue" if trust_level == "yellow"
    trust_value = User.trust_levels[trust_level]
    render json: {
      trust_level: trust_level,
      trust_value: trust_value
    }
  end

  def user_projects
    return render json: { error: "User not found" }, status: :not_found unless @user

    since = 30.days.ago.beginning_of_day
    projects = @user.heartbeats
      .where("time >= ?", since)
      .where.not(project: [ nil, "" ])
      .select(:project)
      .distinct
      .pluck(:project)

    render json: { projects: projects }
  end

  def user_project
    return render json: { error: "User not found" }, status: :not_found unless @user
    project_name = params[:project_name]
    return render json: { error: "whats the name?" }, status: :bad_request unless project_name.present?

    heartbeats = @user.heartbeats.where(project: project_name)
    return render json: { error: "found nuthin" }, status: :not_found if heartbeats.empty?

    repo_url = heartbeats.where.not(repo_url: [ nil, "" ]).order(time: :desc).limit(1).pluck(:repo_url).first
    last_commit = heartbeats.where.not(commit: [ nil, "" ]).order(time: :desc).limit(1).pluck(:commit).first
    languages = heartbeats.where.not(language: [ nil, "" ]).distinct.pluck(:language)

    render json: {
      project: project_name,
      repo_url: repo_url,
      last_commit: last_commit,
      languages: languages
    }
  end

  private

  def set_user
    token = request.headers["Authorization"]&.split(" ")&.last
    identifier = params[:username] || params[:username_or_id] || params[:user_id]

    @user = begin
      if identifier == "my" && token.present?
        ApiKey.find_by(token: token)&.user
      else
        User.find_by(id: identifier) ||
          User.find_by(slack_uid: identifier) ||
          User.find_by(username: identifier)
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
