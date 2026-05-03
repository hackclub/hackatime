class ApplicationController < ActionController::Base
  include ErrorReporting
  include Pundit::Authorization

  before_action :set_paper_trail_whodunnit
  before_action :sentry_context, if: :current_user
  before_action :initialize_cache_counters
  before_action :try_rack_mini_profiler_enable
  before_action :track_request
  before_action :enforce_lockout
  before_action :set_cache_headers

  around_action :switch_time_zone, if: :current_user

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :policy

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

  def track_request
    RequestCounter.increment
  end

  def try_rack_mini_profiler_enable
    if current_user && policy(:admin).mini_profiler?
      Rack::MiniProfiler.authorize_request
    end
  end

  # Pundit needs `current_user` defined before policies are instantiated.
  # The default Pundit `pundit_user` already returns `current_user`, but
  # we override here in case a subclass redefines `current_user` (e.g. the
  # admin API uses an admin_api_key-derived user).
  def pundit_user
    current_user
  end

  def user_not_authorized(exception)
    respond_to do |format|
      format.json { render json: { error: "lmao no perms" }, status: :forbidden }
      format.html do
        flash[:alert] = "You are not authorized to access this page."
        redirect_back fallback_location: root_path
      end
      format.any { head :forbidden }
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
      redirect_to root_path, alert: "Please sign in first!"
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

  def initialize_cache_counters
    Thread.current[:cache_hits] = 0
    Thread.current[:cache_misses] = 0
  end

  def increment_cache_hits
    Thread.current[:cache_hits] += 1
  end

  def increment_cache_misses
    Thread.current[:cache_misses] += 1
  end

  def active_users_graph_data
    Cache::ActiveUsersGraphDataJob.perform_now
  end
end
