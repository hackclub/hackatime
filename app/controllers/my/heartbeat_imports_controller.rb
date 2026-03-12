class My::HeartbeatImportsController < ApplicationController
  before_action :ensure_current_user

  def create
    if params[:heartbeat_file].blank? && params[:heartbeat_import].blank?
      render json: { error: "No import data provided." }, status: :unprocessable_entity
      return
    end

    run = if params[:heartbeat_file].present?
      start_dev_upload!
    else
      start_remote_import!
    end

    render json: {
      import_id: run.id.to_s,
      status: HeartbeatImportRunner.serialize(run)
    }, status: :accepted
  rescue DevelopmentOnlyError => e
    render json: { error: e.message }, status: :forbidden
  rescue HeartbeatImportRunner::FeatureDisabledError => e
    render json: { error: e.message }, status: :not_found
  rescue HeartbeatImportRunner::CooldownError => e
    render json: { error: e.message, retry_at: e.retry_at.iso8601 }, status: :too_many_requests
  rescue HeartbeatImportRunner::ActiveImportError => e
    render json: { error: e.message }, status: :conflict
  rescue HeartbeatImportRunner::InvalidProviderError, ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue => e
    Sentry.capture_exception(e)
    Rails.logger.error("Error starting heartbeat import for user #{current_user&.id}: #{e.message}")
    render json: { error: "error reading file: #{e.message}" }, status: :internal_server_error
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
    if heartbeat_import[:api_key].blank?
      raise HeartbeatImportRunner::InvalidProviderError, "API key is required."
    end

    HeartbeatImportRunner.start_remote_import(
      user: current_user,
      provider: heartbeat_import[:provider],
      api_key: heartbeat_import[:api_key]
    )
  end

  def ensure_current_user
    return if current_user

    render json: { error: "You must be logged in to view this page." }, status: :unauthorized
  end

  def ensure_development
    return if Rails.env.development?

    raise DevelopmentOnlyError, "Heartbeat import is only available in development."
  end

  def remote_import_params
    params.require(:heartbeat_import).permit(:provider, :api_key)
  end
end
