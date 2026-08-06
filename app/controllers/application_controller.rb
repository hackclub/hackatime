class ApplicationController < ActionController::Base
  include ErrorReporting
  include RenderHelpers
  include AuthHelpers
  include AdminApiKeyAuthentication

  before_action :set_paper_trail_whodunnit
  before_action :sentry_context, if: :current_user
  before_action :try_rack_mini_profiler_enable
  before_action :enforce_lockout
  before_action :set_cache_headers

  around_action :switch_time_zone, if: :current_user
  after_action :persist_theme_cookie, if: :current_user

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
    return @current_user if defined?(@current_user)

    @current_user = resolve_session_user
  end

  def resolve_session_user
    return unless session[:user_id]

    user = User.find_by(id: session[:user_id])
    session_version = session[:authentication_version] || 0
    return user if user&.authentication_allowed? && user.authentication_version == session_version.to_i

    reset_session
    nil
  end

  def user_signed_in?
    !!current_user
  end

  def persist_theme_cookie
    return if cookies[:hackatime_theme] == current_user.theme

    cookies.permanent[:hackatime_theme] = {
      value: current_user.theme,
      httponly: false,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def safe_return_url(url)
    return nil if url.blank?
    return nil if url.match?(/[\\\x00-\x1F\x7F]/)

    uri = URI.parse(url)
    return nil if uri.scheme || uri.host || !uri.path.start_with?("/") || uri.path.start_with?("//")

    url
  rescue URI::InvalidURIError
    nil
  end

  # Build a return_data hash from a continue URL, extracting known query
  # params (like skip_setup_flow) so they survive auth redirects.
  def build_return_data(continue_url)
    url = safe_return_url(continue_url)
    return {} if url.blank?

    data = { "url" => url }
    query = Rack::Utils.parse_query(URI.parse(url).query.to_s)
    data["skip_setup_flow"] = true if query.key?("skip_setup_flow")
    data["button_text"] = query["button_text"] if query["button_text"].present?
    data
  rescue URI::InvalidURIError
    { "url" => url }
  end

  def authenticate_user!
    unless user_signed_in?
      redirect_to signin_path(continue: request.fullpath), alert: "Please sign in first!"
    end
  end

  # Authenticates stats integrations with an AdminApiKey. STATS_API_KEY remains
  # available as a temporary fallback while the Flipper flag is enabled.
  def authenticate_stats_api_key!(allow_query_param: true, message: "Unauthorized")
    header_token = request.headers["Authorization"]&.split(" ")&.last
    if header_token.present?
      return if auth_admin_api_key(header_token)
      return if valid_legacy_stats_api_key?(header_token)
    elsif allow_query_param
      return if valid_legacy_stats_api_key?(params[:api_key])
    end

    render_unauthorized(message)
  end

  def valid_legacy_stats_api_key?(token)
    return false unless Flipper.enabled?(:allow_legacy_stats_api_key)

    expected = ENV["STATS_API_KEY"]
    token.present? && expected.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
  end

  def oauth_bearer_user(required_scopes = [])
    @oauth_bearer_users ||= {}
    @oauth_bearer_users[required_scopes] ||= begin
      scheme, raw_token = request.headers["Authorization"].to_s.split(/\s+/, 2)
      if scheme&.casecmp?("Bearer") && raw_token.present?
        token = Doorkeeper::AccessToken.by_token(raw_token)
        if token&.acceptable?(required_scopes)
          user = User.find_by(id: token.resource_owner_id)
          user unless user&.api_access_restricted?
        end
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
