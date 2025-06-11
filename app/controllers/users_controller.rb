class UsersController < ApplicationController
  include ActionView::Helpers::NumberHelper

  before_action :set_user
  before_action :require_current_user, except: [ :update_trust_level ]
  before_action :require_admin, only: [ :update_trust_level ]

  def edit
    @can_enable_slack_status = @user.slack_access_token.present? && @user.slack_scopes.include?("users.profile:write")

    @enabled_sailors_logs = SailorsLogNotificationPreference.where(
      slack_uid: @user.slack_uid,
      enabled: true,
    ).where.not(slack_channel_id: SailorsLog::DEFAULT_CHANNELS)

    @heartbeats_migration_jobs = @user.data_migration_jobs

    @projects = @user.project_repo_mappings.distinct.pluck(:project_name)
    @work_time_stats_url = "https://hackatime-badge.hackclub.com/#{@user.slack_uid}/#{@projects.first || 'example'}"
  end

  def update
    # Handle timezone leaderboard toggle
    if params[:toggle_timezone_leaderboard] == "1"
      if Flipper.enabled?(:timezone_leaderboard, @user)
        Flipper.disable(:timezone_leaderboard, @user)
        message = "Regional & Timezone Leaderboards disabled"
      else
        Flipper.enable(:timezone_leaderboard, @user)
        message = "Regional & Timezone Leaderboards enabled"
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "timezone_leaderboard_toggle",
            partial: "timezone_leaderboard_toggle",
            locals: { user: @user }
          )
        end
        format.html do
          redirect_to is_own_settings? ? my_settings_path : settings_user_path(@user),
            notice: message
        end
      end
      return
    end

    # Handle regular user settings updates
    if params[:user].present?
      if @user.update(user_params)
        if @user.uses_slack_status?
          @user.update_slack_status
        end
        redirect_to is_own_settings? ? my_settings_path : settings_user_path(@user),
          notice: "Settings updated successfully"
      else
        flash[:error] = "Failed to update settings"
        render :settings, status: :unprocessable_entity
      end
    else
      redirect_to is_own_settings? ? my_settings_path : settings_user_path(@user),
        notice: "Settings updated successfully"
    end
  end

  def migrate_heartbeats
    MigrateUserFromHackatimeJob.perform_later(@user.id)

    redirect_to is_own_settings? ? my_settings_path : settings_user_path(@user),
      notice: "Heartbeats & api keys migration started"
  end

  def wakatime_setup
    api_key = current_user&.api_keys&.last
    api_key ||= current_user.api_keys.create!(name: "Wakatime API Key")
    @current_user_api_key = api_key&.token
  end

  def wakatime_setup_step_2
  end

  def wakatime_setup_step_3
  end

  def wakatime_setup_step_4
    @no_instruction_wording = [
      "There is no step 4, lol.",
      "There is no step 4, psych!",
      "Tricked ya! There is no step 4.",
      "There is no step 4, gotcha!"
    ].sample
  end

  def update_trust_level
    @user = User.find(params[:id])
    require_admin

    if @user.update(trust_level: params[:trust_level])
      render json: { status: "success" }
    else
      render json: { status: "error", message: @user.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  private

  def require_admin
    unless current_user.admin?
      redirect_to root_path, alert: "You are not authorized to access this page"
    end
  end

  def require_current_user
    unless @user == current_user
      redirect_to root_path, alert: "You are not authorized to access this page"
    end
  end

  def set_user
    @user = if params["id"].present?
      User.find(params["id"])
    else
      current_user
    end

    redirect_to root_path, alert: "You need to log in!" if @user.nil?
  end

  def is_own_settings?
    @is_own_settings ||= params["id"] == "my" || params["id"]&.blank?
  end

  def user_params
    params.require(:user).permit(:uses_slack_status, :hackatime_extension_text_type, :timezone, :allow_public_stats_lookup)
  end
end
