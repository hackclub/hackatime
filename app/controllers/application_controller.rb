class ApplicationController < ActionController::Base
  before_action :set_paper_trail_whodunnit
  before_action :sentry_context, if: :current_user
  before_action :initialize_cache_counters
  before_action :try_rack_mini_profiler_enable
  before_action :track_request
  before_action :set_public_activity
  before_action :enforce_lockout
  after_action :track_action

  around_action :switch_time_zone, if: :current_user

  def switch_time_zone(&block)
    Time.use_zone(current_user.timezone, &block)
  end

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  helper_method :current_user, :user_signed_in?, :active_users_graph_data

  private

  def set_public_activity
    return unless Flipper.enabled?(:public_activity_log, current_user)
    @activities = PublicActivity::Activity.limit(25).order(created_at: :desc).includes(:owner, :trackable)
  end

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

  def track_action
    ahoy.track "Ran action", request.path_parameters
  end

  def track_request
    RequestCounter.increment
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
