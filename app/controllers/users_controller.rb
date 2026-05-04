class UsersController < InertiaController
  layout "inertia", only: %i[wakatime_setup wakatime_setup_step_2 wakatime_setup_step_3 wakatime_setup_step_4]

  before_action :ensure_current_user_for_setup, only: %i[wakatime_setup wakatime_setup_step_2 wakatime_setup_step_3 wakatime_setup_step_4]
  before_action :set_wakatime_setup_meta, only: %i[wakatime_setup wakatime_setup_step_2 wakatime_setup_step_3 wakatime_setup_step_4]
  before_action :set_target_user, only: [ :update_trust_level ]
  before_action :authorize_trust_change!, only: [ :update_trust_level ]

  def wakatime_setup
    api_key = current_user&.api_keys&.last
    api_key ||= current_user.api_keys.create!(name: "Wakatime API Key")

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
    api_key = current_user&.api_keys&.last
    api_key ||= current_user.api_keys.create!(name: "Wakatime API Key")

    render inertia: "WakatimeSetup/Step3", props: {
      current_user_api_key: api_key.token,
      editor: params[:editor]
    }
  end

  def wakatime_setup_step_4
    render inertia: "WakatimeSetup/Step4", props: {
      dino_video_url: FlavorText.dino_meme_videos.sample,
      return_url: session.dig(:return_data, "url"),
      return_button_text: session.dig(:return_data, "button_text") || "Done"
    }
  end

  def update_trust_level
    trust_level = params[:trust_level]
    reason = params[:reason]
    notes = params[:notes]

    return render json: { error: "lmao no perms" }, status: :unprocessable_entity if trust_level.blank?

    unless User.trust_levels.key?(trust_level)
      return render json: { error: "you fucked it up lmaooo" }, status: :unprocessable_entity
    end

    if trust_level == "red" && !policy(@user).convict?
      return render json: { error: "no perms lmaooo" }, status: :forbidden
    end

    success = @user.set_trust(
      trust_level,
      changed_by_user: current_user,
      reason: reason,
      notes: notes
    )

    if success
      render json: {
        success: true,
        message: "updated",
        trust_level: @user.trust_level
      }
    else
      render json: { error: "402 invalid" }, status: :unprocessable_entity
    end
  end

  private

  def ensure_current_user_for_setup
    redirect_to signin_path(continue: request.fullpath), alert: "Please sign in to set up your editor." if current_user.nil?
  end

  def set_wakatime_setup_meta
    @page_title       = "Set Up Your Editor - Hackatime"
    @meta_description = "Connect your code editor to Hackatime in minutes. Install the WakaTime plugin and start tracking your coding time for free."
    @og_title         = "Set Up Your Editor - Hackatime"
    @og_description   = "Connect your code editor to Hackatime in minutes. Install the WakaTime plugin and start tracking your coding time for free."
  end

  def set_target_user
    @user = User.find(params[:id])
  end

  # Authorize the target trust change. We rescue Pundit::NotAuthorizedError
  # locally because this endpoint returns JSON, but the controller as a
  # whole inherits from InertiaController (HTML default). The default
  # ApplicationController rescue would `redirect_back` which is wrong here.
  def authorize_trust_change!
    authorize @user, :update_trust_level?
  rescue Pundit::NotAuthorizedError
    render json: { error: "lmao no perms" }, status: :forbidden
  end

  def require_current_user
    unless @user == current_user
      redirect_to root_path, alert: "You are not authorized to access this page"
    end
  end

  def detect_setup_os(user_agent)
    ua = user_agent.to_s

    return :windows if ua.match?(/windows/i)

    :mac_linux
  end
end
