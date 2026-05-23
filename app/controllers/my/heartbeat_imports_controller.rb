class My::HeartbeatImportsController < ApplicationController
  layout "inertia"

  before_action :ensure_current_user, only: %i[create show]
  before_action :authenticate_user!, only: :wakatime_download_link

  IMPORT_RESCUE_CLASSES = [
    HeartbeatImportRunner::FeatureDisabledError,
    HeartbeatImportRunner::ActiveImportError,
    HeartbeatImportRunner::InvalidDownloadUrlError,
    HeartbeatImportRunner::InvalidProviderError,
    ActionController::ParameterMissing
  ].freeze

  def create
    if params[:heartbeat_file].blank? && params[:heartbeat_import].blank?
      redirect_with_import_error("No import data provided.")
      return
    end

    params[:heartbeat_file].present? ? start_dev_upload! : start_remote_import!
    redirect_to my_settings_imports_exports_path
  rescue DevelopmentOnlyError => e
    redirect_with_import_error(e.message)
  rescue HeartbeatImportRunner::CooldownError => e
    flash[:cooldown_until] = e.retry_at.iso8601
    redirect_with_import_error(e.message)
  rescue *IMPORT_RESCUE_CLASSES => e
    redirect_with_import_error(e.message)
  rescue => e
    report_error(e, message: "Error starting heartbeat import for user #{current_user&.id}")
    redirect_with_import_error("error reading file: #{e.message}")
  end

  def show
    run = HeartbeatImportRunner.find_run(user: current_user, import_id: params[:id])
    if run.present?
      run = HeartbeatImportRunner.refresh_remote_run!(run)
      render json: HeartbeatImportRunner.serialize(run)
    else
      render_not_found_json("Import not found")
    end
  end

  def wakatime_download_link
    render inertia: "HeartbeatImports/WakatimeDownloadLink", props: { page_title: "Paste your WakaTime export link" }
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
      HeartbeatImportRunner.start_wakatime_download_link_import(user: current_user, download_url: heartbeat_import[:download_url])
      return
    end

    raise HeartbeatImportRunner::InvalidProviderError, "API key is required." if heartbeat_import[:api_key].blank?

    HeartbeatImportRunner.start_remote_import(user: current_user,
                                              provider: heartbeat_import[:provider],
                                              api_key: heartbeat_import[:api_key])
  end

  def ensure_development
    raise DevelopmentOnlyError, "Heartbeat import is only available in development." unless Rails.env.development?
  end

  def redirect_with_import_error(message)
    redirect_to my_settings_imports_exports_path, inertia: { errors: { import: message } }
  end

  def remote_import_params = params.require(:heartbeat_import).permit(:provider, :api_key, :download_url)

  def ensure_current_user
    render_unauthorized("You must be logged in to view this page.") unless current_user
  end
end
