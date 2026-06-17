class ApplicationController < ActionController::Base
  include ErrorReporting
  include RenderHelpers
  include AuthHelpers

  before_action :set_paper_trail_whodunnit
  before_action :sentry_context, if: :current_user
  before_action :try_rack_mini_profiler_enable
  before_action :enforce_lockout
  before_action :set_cache_headers

  around_action :switch_time_zone, if: :current_user

  def switch_time_zone(&block)
    Time.use_zone(current_user.timezone, &block)
  end

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  helper_method :current_user, :user_signed_in?, :active_users_graph_data

  private

  def sentry_context
    Sentry.set_user(
      id: current_user.id,
      username: current_user.username
    )
    Sentry.set_extras(
      user_agent: request.user_agent,
      ip_address: request.headers["CF-Connecting-IP"] || request.remote_ip
    )
  end

  def try_rack_mini_profiler_enable
    if current_user && (current_user.admin_level == "admin" || current_user.admin_level == "superadmin")
      Rack::MiniProfiler.authorize_request
    end
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    !!current_user
  end

  def safe_return_url(url)
    return nil if url.blank?
    return nil unless url.start_with?("/") && !url.start_with?("//")
    url
  end

  def authenticate_user!
    unless user_signed_in?
      redirect_to signin_path(continue: request.fullpath), alert: "Please sign in first!"
    end
  end

  # Authenticates requests using the shared STATS_API_KEY env var (used by
  # internal/admin-style API endpoints). Token may come from an Authorization
  # header ("Bearer <token>") or, when allowed, an `api_key` query param.
  def authenticate_legacy_stats_api_key!(allow_query_param: true, message: "Unauthorized")
    expected = ENV["STATS_API_KEY"]
    return render_unauthorized(message) if expected.blank?
    token = request.headers["Authorization"]&.split(" ")&.last
    token ||= params[:api_key] if allow_query_param
    render_unauthorized(message) unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
  end

  def oauth_bearer_user
    @oauth_bearer_user ||= begin
      scheme, raw_token = request.headers["Authorization"].to_s.split(/\s+/, 2)
      if scheme == "Bearer" && raw_token.present?
        token = Doorkeeper::AccessToken.by_token(raw_token)
        User.find_by(id: token.resource_owner_id) if token&.acceptable?([])
      end
    end
  end

  def enforce_lockout
    return unless current_user&.pending_deletion?
    return if %w[deletion_requests sessions].include?(controller_name)
    redirect_to deletion_path
  end

  def set_cache_headers
    response.headers["Cache-Control"] = "no-store"
  end

  def active_users_graph_data
    Cache::ActiveUsersGraphDataJob.perform_now
  end
end
