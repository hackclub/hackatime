class UsersController < InertiaController
  SETUP_THEME = "rose_pine_dawn".freeze

  layout "inertia", only: %i[setup]

  before_action :ensure_current_user_for_setup, only: %i[setup]
  before_action :set_setup_meta, only: %i[setup]
  before_action :require_admin, only: [ :update_trust_level ]

  # The setup flow forces its own light theme regardless of the user's choice.
  helper_method :current_theme, :current_theme_color_scheme, :current_theme_color

  def setup
    # Hardware-program users skip editor setup and land directly on the
    # finish screen.
    skip_setup_flow = session.dig(:return_data, "skip_setup_flow").present? || params[:skip_setup_flow].present?
    session[:return_data]&.delete("skip_setup_flow")

    render inertia: "Setup/Index", props: {
      current_user_api_key: ensure_api_key.token,
      setup_os: detect_setup_os(request.user_agent).to_s,
      skip_setup_flow: skip_setup_flow,
      return_url: session.dig(:return_data, "url"),
      return_button_text: session.dig(:return_data, "button_text") || "Done"
    }
  end

  def update_trust_level
    @user = User.find(params[:id])
    trust_level = params[:trust_level]

    return render_error("lmao no perms") unless @user && trust_level.present?
    return render_error("you fucked it up lmaooo") unless User.trust_levels.key?(trust_level)
    return render_forbidden("no perms lmaooo") unless current_user.can_change_trust_of?(@user, trust_level)

    success = @user.set_trust(
      trust_level,
      changed_by_user: current_user,
      reason: params[:reason],
      notes: params[:notes]
    )

    if success
      render json: { success: true, message: "updated", trust_level: @user.trust_level }
    else
      render_error("402 invalid")
    end
  end

  private

  def inertia_layout_props
    super.merge(hide_sidebar: true, hide_footer: true)
  end

  def inertia_theme_props
    {
      name: SETUP_THEME,
      color_scheme: current_theme_color_scheme,
      theme_color: current_theme_color
    }
  end

  def current_theme = SETUP_THEME
  def current_theme_color_scheme = User.theme_metadata(SETUP_THEME).fetch(:color_scheme, "light")
  def current_theme_color = User.theme_metadata(SETUP_THEME).fetch(:theme_color, "#aa586f")

  def ensure_api_key
    current_user&.api_keys&.last || current_user.api_keys.create!(name: "Wakatime API Key")
  end

  def ensure_current_user_for_setup
    redirect_to signin_path(continue: request.fullpath), alert: "Please sign in to set up your editor." if current_user.nil?
  end

  def set_setup_meta
    @page_title = @og_title = "Set Up Your Editor - Hackatime"
    @meta_description = @og_description = "Connect your code editor to Hackatime in minutes. Install the WakaTime plugin and start tracking your coding time for free."
  end

  def require_admin = require_admin!

  def detect_setup_os(user_agent)
    ua = user_agent.to_s
    return :windows if ua.match?(/windows/i)
    return :mac if ua.match?(/macintosh|mac os x/i)
    return :linux if ua.match?(/linux|x11/i)

    :mac
  end
end
