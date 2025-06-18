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
    # Handle setting toggles
    if params[:toggle_timezone_leaderboard] == "1"
      handle_timezone_leaderboard_toggle
      return
    elsif params[:toggle_public_stats] == "1"
      handle_public_stats_toggle
      return
    elsif params[:toggle_slack_status] == "1"
      handle_slack_status_toggle
      return
    end

    # Handle regular user settings updates
    if params[:user].present?
      if @user.update(user_params)
        if @user.uses_slack_status?
          @user.update_slack_status
        end

        respond_to do |format|
          format.turbo_stream do
            if params[:user][:hackatime_extension_text_type].present?
              render turbo_stream: turbo_stream.replace(
                "extension_settings",
                partial: "extension_settings",
                locals: { user: @user }
              )
            else
              head :ok
            end
          end
          format.html do
            redirect_to is_own_settings? ? my_settings_path : settings_user_path(@user),
              notice: "Settings updated successfully"
          end
        end
      else
        respond_to do |format|
          format.turbo_stream { head :unprocessable_entity }
          format.html do
            flash[:error] = "Failed to update settings"
            render :edit, status: :unprocessable_entity
          end
        end
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

  def handle_timezone_leaderboard_toggle
    if Flipper.enabled?(:timezone_leaderboard, @user)
      Flipper.disable(:timezone_leaderboard, @user)
    else
      Flipper.enable(:timezone_leaderboard, @user)
    end

    render_setting_toggle("timezone_leaderboard")
  end

  def handle_public_stats_toggle
    @user.update!(allow_public_stats_lookup: !@user.allow_public_stats_lookup?)
    render_setting_toggle("privacy_settings")
  end

  def handle_slack_status_toggle
    @user.update!(uses_slack_status: !@user.uses_slack_status?)
    @user.update_slack_status if @user.uses_slack_status?
    render_setting_toggle("slack_status")
  end

  def render_setting_toggle(partial_name)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "#{partial_name}_toggle",
          partial: "#{partial_name}_toggle",
          locals: { user: @user }
        )
      end
      format.html { redirect_to is_own_settings? ? my_settings_path : settings_user_path(@user) }
    end
  end

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
