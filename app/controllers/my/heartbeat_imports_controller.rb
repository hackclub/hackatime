class My::HeartbeatImportsController < ApplicationController
  before_action :ensure_current_user
  before_action :ensure_development

  def create
    unless params[:heartbeat_file].present?
      render json: { error: "pls select a file to import" }, status: :unprocessable_entity
      return
    end

    file = params[:heartbeat_file]
    unless valid_json_file?(file)
      render json: { error: "pls upload only json (download from the button above it)" }, status: :unprocessable_entity
      return
    end

    import_id = HeartbeatImportRunner.start(user: current_user, uploaded_file: file)
    status = HeartbeatImportRunner.status(user: current_user, import_id: import_id)

    render json: {
      import_id: import_id,
      status: status
    }, status: :accepted
  rescue => e
    Sentry.capture_exception(e)
    Rails.logger.error("Error starting heartbeat import for user #{current_user&.id}: #{e.message}")
    render json: { error: "error reading file: #{e.message}" }, status: :internal_server_error
  end

  def show
    status = HeartbeatImportRunner.status(user: current_user, import_id: params[:id])
    if status.present?
      render json: status
    else
      render json: { error: "Import not found" }, status: :not_found
    end
  end

  private

  def valid_json_file?(file)
    file.content_type == "application/json" || file.original_filename.to_s.ends_with?(".json")
  end

  def ensure_current_user
    return if current_user

    render json: { error: "You must be logged in to view this page." }, status: :unauthorized
  end

  def ensure_development
    return if Rails.env.development?

    render json: { error: "Heartbeat import is only available in development." }, status: :forbidden
  end
end
