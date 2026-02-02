class Api::V1::StatsController < ApplicationController
  before_action :ensure_authenticated!, only: [ :show ], unless: -> { Rails.env.development? }
  before_action :set_user, only: [ :user_stats, :user_spans, :user_projects, :user_project, :user_projects_details ]

  def show
    # take either user_id with a start date & end date
    start_date = Date.parse(params[:start_date]).beginning_of_day if params[:start_date].present?
    start_date ||= 10.years.ago
    end_date = Date.parse(params[:end_date]).end_of_day if params[:end_date].present?
    end_date ||= Date.today.end_of_day

    query = Heartbeat.where(time: start_date..end_date)
    if params[:username].present?
      user = User.find_by(username: params[:username]) || User.find_by(slack_uid: params[:username])
      return render json: { error: "User not found" }, status: :not_found unless user

      query = query.where(user_id: user.id)
    end

    if params[:user_email].present?
      user_id = EmailAddress.find_by(email: params[:user_email])&.user_id || find_by_email(params[:user_email])

      return render json: { error: "User not found" }, status: :not_found unless user_id.present?

      query = query.where(user_id: user_id)
    end

    render plain: query.duration_seconds.to_s
  end

  def user_stats
    # Used by the github stats page feature

    return render json: { error: "User not found" }, status: :not_found unless @user.present?

    if !@user.allow_public_stats_lookup && (!current_user || current_user != @user)
      return render json: { error: "user has disabled public stats" }, status: :forbidden
    end

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

    # use TestWakatimeService when test_param=true for all requests
    if params[:test_param] == "true"
      service_params[:boundary_aware] = true  # always and i mean always use boundary aware in testwakatime service

      if params[:total_seconds] == "true"
        summary = TestWakatimeService.new(**service_params).generate_summary
        return render json: { total_seconds: summary[:total_seconds] }
      end

      summary = TestWakatimeService.new(**service_params).generate_summary
    else
      if params[:total_seconds] == "true"
        query = @user.heartbeats
                     .coding_only
                     .with_valid_timestamps
                     .where(time: start_date..end_date)

        if params[:filter_by_project].present?
          filter_by_project = params[:filter_by_project].split(",")
          query = query.where(project: filter_by_project)
        end

        if params[:filter_by_category].present?
          filter_by_category = params[:filter_by_category].split(",")
          query = query.where(category: filter_by_category)
        end

        # do the boundary thingie if requested
        use_boundary_aware = params[:boundary_aware] == "true"
        total_seconds = if use_boundary_aware
          Heartbeat.duration_seconds_boundary_aware(query, start_date.to_f, end_date.to_f) || 0
        else
          query.duration_seconds || 0
        end

        return render json: { total_seconds: total_seconds }
      end

      summary = WakatimeService.new(**service_params).generate_summary
    end

    if params[:features]&.include?("projects") && params[:filter_by_project].present?
      filter_by_project = params[:filter_by_project].split(",")
      heartbeats = @user.heartbeats
        .coding_only
        .with_valid_timestamps
        .where(time: start_date..end_date, project: filter_by_project)
      unique_seconds = unique_heartbeat_seconds(heartbeats)
      summary[:unique_total_seconds] = unique_seconds
    end



    trust_level = @user.trust_level
    trust_level = "blue" if trust_level == "yellow"
    trust_value = User.trust_levels[trust_level]
    trust_info = {
      trust_level: trust_level,
      trust_value: trust_value
    }

    summary[:streak] = @user.streak_days

    render json: {
      data: summary,
      trust_factor: trust_info
    }
  end

  def user_spans
    return render json: { error: "User not found" }, status: :not_found unless @user

    start_date = params[:start_date].to_datetime if params[:start_date].present?
    start_date ||= 10.years.ago
    end_date = params[:end_date].to_datetime if params[:end_date].present?
    end_date ||= Date.today.end_of_day

    timespan = (start_date.to_f..end_date.to_f)

    heartbeats = @user.heartbeats.where(time: timespan)

    if params[:project].present?
      heartbeats = heartbeats.where(project: params[:project])
    elsif params[:filter_by_project].present?
      heartbeats = heartbeats.where(project: params[:filter_by_project].split(","))
    end

    render json: { spans: heartbeats.to_span }
  end

  def trust_factor
    id = params[:username] || params[:username_or_id] || params[:user_id]
    return render json: { error: "User not found" }, status: :not_found if id.blank?

    query = User.where(slack_uid: id).or(User.where(username: id))
    query = query.or(User.where(id: id)) if id.match?(/^\d+$/)
    level = query.pick(:trust_level)

    return render json: { error: "User not found" }, status: :not_found unless level

    level = "blue" if level == "yellow"
    render json: { trust_level: level, trust_value: User.trust_levels[level] }
  end

  def user_projects
    return render json: { error: "User not found" }, status: :not_found unless @user

    since = 30.days.ago.beginning_of_day.to_f
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

    project_data = get_project([ project_name ]).first
    return render json: { error: "found nuthin" }, status: :not_found unless project_data

    render json: project_data
  end

  def user_projects_details
    return render json: { error: "User not found" }, status: :not_found unless @user

    names = if params[:projects].present?
      params[:projects].split(",").map(&:strip)
    else
      since = params[:since]&.to_datetime || 30.days.ago.beginning_of_day
      until_date = (params[:until] || params[:until_date])&.to_datetime || Time.current

      @user.heartbeats
           .where(time: since..until_date)
           .where.not(project: [ nil, "" ])
           .select(:project)
           .distinct
           .pluck(:project)
    end

    return render json: { projects: [] } if names.empty?

    data = get_project(names)
    render json: { projects: data }
  end

  private

  def set_user
    token = request.headers["Authorization"]&.split(" ")&.last
    identifier = params[:username] || params[:username_or_id] || params[:user_id]

    @user = begin
      if identifier == "my" && token.present?
        ApiKey.find_by(token: token)&.user
      else
        lookup_user(identifier)
      end
    end
  end

  def lookup_user(id)
    return nil if id.blank?

    if id.match?(/^\d+$/)
      user = User.find_by(id: id)
      return user if user
    end

    user = User.find_by(slack_uid: id)
    return user if user

    # email lookup, but you really should not be using this cuz like wtf
    # if identifier.include?("@")
    #   email_record = EmailAddress.find_by(email: identifier)
    #   return email_record.user if email_record
    # end

    user = User.find_by(username: id)
    return user if user

    # skill issue zone
    nil
  end

  def ensure_authenticated!
    token = request.headers["Authorization"]&.split(" ")&.last
    token ||= params[:api_key]

    # Rails.logger.info "Auth Debug: Token=#{token.inspect}, Expected=#{ENV['STATS_API_KEY'].inspect}"
    render json: { error: "Unauthorized" }, status: :unauthorized unless token == ENV["STATS_API_KEY"]
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

  def get_project(names)
    start_date = params[:start_date]&.to_datetime || 1.year.ago
    end_date = params[:end_date]&.to_datetime || Time.current

    query = @user.heartbeats
                 .where(time: start_date..end_date)
                 .where(project: names)

    return [] if query.empty?

    stats = query
           .group(:project)
           .select("project,
                   COUNT(*) as heartbeat_count,
                   MIN(time) as first_heartbeat,
                   MAX(time) as last_heartbeat")

    data = []

    names.each do |name|
      heartbeats = query.where(project: name)
      next if heartbeats.empty?

      seconds = heartbeats.duration_seconds || 0
      stat = stats.find { |p| p.project == name }

      languages = heartbeats
                 .where.not(language: [ nil, "" ])
                 .select(:language)
                 .distinct
                 .pluck(:language)

      repo = @user.project_repo_mappings.find_by(project_name: name)
      next if repo&.archived?

      data << {
        name: name,
        total_seconds: seconds,
        languages: languages,
        repo_url: repo&.repo_url,
        total_heartbeats: stat&.heartbeat_count || 0,
        first_heartbeat: stat&.first_heartbeat ? Time.at(stat.first_heartbeat).strftime("%Y-%m-%dT%H:%M:%SZ") : nil,
        last_heartbeat: stat&.last_heartbeat ? Time.at(stat.last_heartbeat).strftime("%Y-%m-%dT%H:%M:%SZ") : nil
      }
    end

    data.sort_by { |project| -project[:total_seconds] }
  end

  def unique_heartbeat_seconds(heartbeats)
    timestamps = heartbeats.order(:time).pluck(:time)
    return 0 if timestamps.empty?

    total_seconds = 0
    timestamps.each_cons(2) do |prev_time, curr_time|
      gap = curr_time - prev_time
      if gap > 0 && gap <= 2.minutes
        total_seconds += gap
      end
    end

    total_seconds.to_i
  end
end
