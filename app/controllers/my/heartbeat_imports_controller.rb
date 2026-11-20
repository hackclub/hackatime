class My::HeartbeatImportsController < ApplicationController
  layout "inertia"

  before_action :ensure_current_user, only: %i[create show]
  before_action :authenticate_user!, only: %i[wakatime_download_link wakatime_authorize wakatime_callback]

  IMPORT_RESCUE_CLASSES = [
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

  def wakatime_authorize
    HeartbeatImportRunner.ensure_no_active_import!(current_user)
    HeartbeatImportRunner.ensure_remote_cooldown!(current_user)

    session[:wakatime_import_oauth_state] = state = SecureRandom.hex(24)
    redirect_to HeartbeatImportDumpClient.wakatime_authorize_url(redirect_uri: wakatime_callback_my_heartbeat_imports_url, state:),
                allow_other_host: true
  rescue HeartbeatImportRunner::CooldownError => e
    flash[:cooldown_until] = e.retry_at.iso8601
    redirect_with_import_error(e.message)
  rescue HeartbeatImportRunner::ActiveImportError => e
    redirect_with_import_error(e.message)
  end

  def wakatime_callback
    expected_state = session.delete(:wakatime_import_oauth_state)
    if params[:error].present?
      return redirect_with_import_error(params[:error] == "access_denied" ? "WakaTime connection cancelled." : "WakaTime could not connect (#{params[:error]}).")
    end
    unless expected_state.present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, expected_state)
      return redirect_with_import_error("This WakaTime connection attempt is no longer valid. Please connect WakaTime again.")
    end

    token = HeartbeatImportDumpClient.exchange_wakatime_code(code: params[:code].to_s, redirect_uri: wakatime_callback_my_heartbeat_imports_url)
    HeartbeatImportRunner.start_remote_import(user: current_user, provider: "wakatime_dump", api_key: token)
    redirect_to my_settings_imports_exports_path
  rescue HeartbeatImportRunner::CooldownError => e
    WakatimeTokenRevocationJob.revoke_later(token)
    flash[:cooldown_until] = e.retry_at.iso8601
    redirect_with_import_error(e.message)
  rescue HeartbeatImportRunner::ActiveImportError => e
    WakatimeTokenRevocationJob.revoke_later(token)
    redirect_with_import_error(e.message)
  rescue HeartbeatImportDumpClient::ResponseError => e
    report_error(e, message: "WakaTime OAuth token exchange failed for user #{current_user.id}")
    redirect_with_import_error("WakaTime could not connect. Please try again.")
  end

  def wakatime_download_link
    render inertia: "HeartbeatImports/WakatimeDownloadLink", props: { page_title: "Import from WakaTime | Hackatime" }
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

    if HeartbeatImportRunner::PROVIDER_ALIASES[heartbeat_import[:provider].to_s] == "wakatime_dump"
      raise HeartbeatImportRunner::InvalidProviderError, "Use Connect WakaTime to import from WakaTime."
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
