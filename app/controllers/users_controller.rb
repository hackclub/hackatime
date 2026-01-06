class UsersController < ApplicationController
  include ActionView::Helpers::NumberHelper

  before_action :set_user
  before_action :require_current_user, except: [ :update_trust_level ]
  before_action :require_admin, only: [ :update_trust_level ]

  def edit
    prepare_settings_page
  end

  def update
    # Handle regular user settings updates
    if params[:user].present?
      if @user.update(user_params)
        if @user.uses_slack_status?
          @user.update_slack_status
        end
        redirect_to is_own_settings? ? my_settings_path : settings_user_path(@user),
          notice: "Settings updated successfully"
      else
        flash.now[:error] = @user.errors.full_messages.to_sentence.presence || "Failed to update settings"
        prepare_settings_page
        render :edit, status: :unprocessable_entity
      end
    else
      redirect_to is_own_settings? ? my_settings_path : settings_user_path(@user),
        notice: "Settings updated successfully!"
    end
  end

  def migrate_heartbeats
    MigrateUserFromHackatimeJob.perform_later(@user.id)

    redirect_to is_own_settings? ? my_settings_path : settings_user_path(@user),
      notice: "Heartbeats & api keys migration started"
  end

  def rotate_api_key
    @user.api_keys.transaction do
      @user.api_keys.destroy_all

      new_api_key = @user.api_keys.create!(name: "Hackatime key")

      render json: { token: new_api_key.token }, status: :ok
    end
  rescue => e
    Rails.logger.error("error rotate #{e.class.name} #{e.message}")
    render json: { error: "cant rotate" }, status: :unprocessable_entity
  end

  def wakatime_setup
    api_key = current_user&.api_keys&.last
    api_key ||= current_user.api_keys.create!(name: "Wakatime API Key")
    @current_user_api_key = api_key&.token
  end

  def wakatime_setup_step_2
  end

  def wakatime_setup_step_3
    api_key = current_user&.api_keys&.last
    api_key ||= current_user.api_keys.create!(name: "Wakatime API Key")
    @current_user_api_key = api_key&.token
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

  def prepare_settings_page
    @is_own_settings = is_own_settings?
    @can_enable_slack_status = @user.slack_access_token.present? && @user.slack_scopes.include?("users.profile:write")

    @enabled_sailors_logs = SailorsLogNotificationPreference.where(
      slack_uid: @user.slack_uid,
      enabled: true,
    ).where.not(slack_channel_id: SailorsLog::DEFAULT_CHANNELS)

    @heartbeats_migration_jobs = @user.data_migration_jobs

    @projects = @user.project_repo_mappings.distinct.pluck(:project_name)
    @work_time_stats_url = "https://hackatime-badge.hackclub.com/#{@user.slack_uid}/#{@projects.first || 'example'}"
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
    params.require(:user).permit(
      :uses_slack_status,
      :hackatime_extension_text_type,
      :timezone,
      :allow_public_stats_lookup,
      :username,
    )
  end
end
