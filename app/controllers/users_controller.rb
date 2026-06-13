class UsersController < InertiaController
  layout "inertia", only: %i[wakatime_setup wakatime_setup_step_2 wakatime_setup_step_3 wakatime_setup_step_4]

  before_action :ensure_current_user_for_setup, only: %i[wakatime_setup wakatime_setup_step_2 wakatime_setup_step_3 wakatime_setup_step_4]
  before_action :set_wakatime_setup_meta, only: %i[wakatime_setup wakatime_setup_step_2 wakatime_setup_step_3 wakatime_setup_step_4]
  before_action :require_admin, only: [ :update_trust_level ]

  def wakatime_setup
    api_key = ensure_api_key

    render inertia: "WakatimeSetup/Index", props: {
      current_user_api_key: api_key.token,
      setup_os: detect_setup_os(request.user_agent).to_s,
      # Full URL (with host) is shown to users in their config file, so we
      # build it server-side rather than via js_from_routes.
      api_url: api_hackatime_v1_url
    }
  end

  def wakatime_setup_step_2
    render inertia: "WakatimeSetup/Step2"
  end

  def wakatime_setup_step_3
    render inertia: "WakatimeSetup/Step3", props: {
      current_user_api_key: ensure_api_key.token, editor: params[:editor]
    }
  end

  def wakatime_setup_step_4
    render inertia: "WakatimeSetup/Step4", props: {
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

  def ensure_api_key
    current_user&.api_keys&.last || current_user.api_keys.create!(name: "Wakatime API Key")
  end

  def ensure_current_user_for_setup
    redirect_to signin_path(continue: request.fullpath), alert: "Please sign in to set up your editor." if current_user.nil?
  end

  def set_wakatime_setup_meta
    @page_title = @og_title = "Set Up Your Editor - Hackatime"
    @meta_description = @og_description = "Connect your code editor to Hackatime in minutes. Install the WakaTime plugin and start tracking your coding time for free."
  end

  def require_admin = require_admin!

  def detect_setup_os(user_agent)
    user_agent.to_s.match?(/windows/i) ? :windows : :mac_linux
  end
end
