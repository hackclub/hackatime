class WakatimeMirrorsController < ApplicationController
  before_action :set_user
  before_action :require_current_user
  before_action :ensure_imports_and_mirrors_enabled
  before_action :set_mirror, only: [ :destroy ]

  def create
    @mirror = @user.wakatime_mirrors.build(mirror_params)
    @mirror.request_host = request.host
    if @mirror.save
      redirect_to my_settings_data_path, notice: "WakaTime mirror added successfully"
    else
      redirect_to my_settings_data_path, alert: "Failed to add WakaTime mirror: #{@mirror.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @mirror.destroy
    redirect_to my_settings_data_path, notice: "WakaTime mirror removed successfully"
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_mirror
    @mirror = @user.wakatime_mirrors.find(params[:id])
  end

  def mirror_params
    params.require(:wakatime_mirror).permit(:endpoint_url, :encrypted_api_key)
  end

  def require_current_user
    unless @user == current_user
      redirect_to root_path, alert: "You are not authorized to access this page"
    end
  end

  def ensure_imports_and_mirrors_enabled
    return if Flipper.enabled?(:wakatime_imports_mirrors)

    redirect_to my_settings_data_path, alert: "Imports and mirrors are currently disabled."
  end
end
