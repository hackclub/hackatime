class UsersController < InertiaController
  layout "inertia", only: %i[wakatime_setup wakatime_setup_step_2 wakatime_setup_step_3 wakatime_setup_step_4]

  before_action :ensure_current_user_for_setup, only: %i[wakatime_setup wakatime_setup_step_2 wakatime_setup_step_3 wakatime_setup_step_4]
  before_action :require_admin, only: [ :update_trust_level ]

  def wakatime_setup
    api_key = current_user&.api_keys&.last
    api_key ||= current_user.api_keys.create!(name: "Wakatime API Key")
    PosthogService.capture(current_user, "setup_started", { step: 1 })

    render inertia: "WakatimeSetup/Index", props: {
      current_user_api_key: api_key.token,
      setup_os: detect_setup_os(request.user_agent).to_s,
      api_url: api_hackatime_v1_url,
      heartbeat_check_url: api_v1_my_heartbeats_most_recent_path(source_type: "test_entry")
    }
  end

  def wakatime_setup_step_2
    PosthogService.capture(current_user, "setup_step_viewed", { step: 2 })

    render inertia: "WakatimeSetup/Step2", props: {}
  end

  def wakatime_setup_step_3
    api_key = current_user&.api_keys&.last
    api_key ||= current_user.api_keys.create!(name: "Wakatime API Key")
    PosthogService.capture(current_user, "setup_step_viewed", { step: 3 })

    render inertia: "WakatimeSetup/Step3", props: {
      current_user_api_key: api_key.token,
      editor: params[:editor],
      heartbeat_check_url: api_v1_my_heartbeats_most_recent_path
    }
  end

  def wakatime_setup_step_4
    PosthogService.capture(current_user, "setup_completed", { step: 4 })

    render inertia: "WakatimeSetup/Step4", props: {
      dino_video_url: FlavorText.dino_meme_videos.sample,
      return_url: session.dig(:return_data, "url"),
      return_button_text: session.dig(:return_data, "button_text") || "Done"
    }
  end

  def update_trust_level
    @user = User.find(params[:id])
    require_admin

    trust_level = params[:trust_level]
    reason = params[:reason]
    notes = params[:notes]

    if @user && (current_user.admin_level == "admin" || current_user.admin_level == "superadmin") && trust_level.present?
      unless User.trust_levels.key?(trust_level)
        return render json: { error: "you fucked it up lmaooo" }, status: :unprocessable_entity
      end

      if trust_level == "red" && current_user.admin_level != "superadmin"
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
    else
      render json: { error: "lmao no perms" }, status: :unprocessable_entity
    end
  end

  private

  def ensure_current_user_for_setup
    redirect_to root_path, alert: "You need to log in!" if current_user.nil?
  end

  def require_admin
    unless current_user && (current_user.admin_level == "admin" || current_user.admin_level == "superadmin")
      redirect_to root_path, alert: "You are not authorized to access this page"
    end
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
