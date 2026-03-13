class My::HeartbeatImportsController < ApplicationController
  layout "inertia"

  before_action :ensure_current_user, only: %i[create show]
  before_action :authenticate_user!, only: :wakatime_download_link

  def create
    if params[:heartbeat_file].blank? && params[:heartbeat_import].blank?
      redirect_with_import_error("No import data provided.")
      return
    end

    if params[:heartbeat_file].present?
      start_dev_upload!
    else
      start_remote_import!
    end

    redirect_to my_settings_data_path
  rescue DevelopmentOnlyError => e
    redirect_with_import_error(e.message)
  rescue HeartbeatImportRunner::FeatureDisabledError => e
    redirect_with_import_error(e.message)
  rescue HeartbeatImportRunner::CooldownError => e
    flash[:cooldown_until] = e.retry_at.iso8601
    redirect_with_import_error(e.message)
  rescue HeartbeatImportRunner::ActiveImportError, HeartbeatImportRunner::InvalidDownloadUrlError => e
    redirect_with_import_error(e.message)
  rescue HeartbeatImportRunner::InvalidProviderError, ActionController::ParameterMissing => e
    redirect_with_import_error(e.message)
  rescue => e
    Sentry.capture_exception(e)
    Rails.logger.error("Error starting heartbeat import for user #{current_user&.id}: #{e.message}")
    redirect_with_import_error("error reading file: #{e.message}")
  end

  def show
    run = HeartbeatImportRunner.find_run(user: current_user, import_id: params[:id])
    if run.present?
      run = HeartbeatImportRunner.refresh_remote_run!(run)
      render json: HeartbeatImportRunner.serialize(run)
    else
      render json: { error: "Import not found" }, status: :not_found
    end
  end

  def wakatime_download_link
    render inertia: "HeartbeatImports/WakatimeDownloadLink", props: {
      page_title: "Paste your WakaTime export link",
      create_heartbeat_import_path: my_heartbeat_imports_path,
      data_settings_path: my_settings_data_path
    }
  end

  private

  class DevelopmentOnlyError < StandardError; end

  def valid_json_file?(file)
    file.content_type == "application/json" || file.original_filename.to_s.ends_with?(".json")
  end

  def start_dev_upload!
    ensure_development

    file = params[:heartbeat_file]
    unless valid_json_file?(file)
      raise HeartbeatImportRunner::InvalidProviderError, "pls upload only json (download from the button above it)"
    end

    HeartbeatImportRunner.start_dev_upload(user: current_user, uploaded_file: file)
  end

  def start_remote_import!
    heartbeat_import = remote_import_params
    if heartbeat_import[:download_url].present?
      HeartbeatImportRunner.start_wakatime_download_link_import(
        user: current_user,
        download_url: heartbeat_import[:download_url]
      )
      return
    end

    if heartbeat_import[:api_key].blank?
      raise HeartbeatImportRunner::InvalidProviderError, "API key is required."
    end

    HeartbeatImportRunner.start_remote_import(
      user: current_user,
      provider: heartbeat_import[:provider],
      api_key: heartbeat_import[:api_key]
    )
  end

  def ensure_development
    return if Rails.env.development?

    raise DevelopmentOnlyError, "Heartbeat import is only available in development."
  end

  def redirect_with_import_error(message)
    redirect_to my_settings_data_path, inertia: { errors: { import: message } }
  end

  def remote_import_params
    params.require(:heartbeat_import).permit(:provider, :api_key, :download_url)
  end

  def ensure_current_user
    return if current_user

    render json: { error: "You must be logged in to view this page." }, status: :unauthorized
  end
end
