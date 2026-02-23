class My::HeartbeatImportSourcesController < ApplicationController
  before_action :ensure_current_user

  def create
    if current_user.heartbeat_import_source.present?
      redirect_to my_settings_data_path, alert: "Import source already configured. Update it instead."
      return
    end

    source = current_user.build_heartbeat_import_source(create_params)
    source.provider = :wakatime_compatible
    source.status = :idle

    if source.save
      HeartbeatImportSourceSyncJob.perform_later(source.id) if source.sync_enabled?
      redirect_to my_settings_data_path, notice: "Import source configured successfully."
    else
      redirect_to my_settings_data_path, alert: source.errors.full_messages.to_sentence
    end
  end

  def update
    source = current_user.heartbeat_import_source
    unless source
      redirect_to my_settings_data_path, alert: "No import source is configured."
      return
    end

    rerun_backfill = ActiveModel::Type::Boolean.new.cast(params.dig(:heartbeat_import_source, :rerun_backfill))
    attrs = update_params
    attrs = attrs.except(:encrypted_api_key) if attrs[:encrypted_api_key].blank?

    if source.update(attrs)
      source.reset_backfill! if rerun_backfill
      HeartbeatImportSourceSyncJob.perform_later(source.id) if source.sync_enabled?
      redirect_to my_settings_data_path, notice: "Import source updated successfully."
    else
      redirect_to my_settings_data_path, alert: source.errors.full_messages.to_sentence
    end
  end

  def show
    source = current_user.heartbeat_import_source
    render json: { import_source: source_payload(source) }
  end

  def destroy
    source = current_user.heartbeat_import_source
    unless source
      redirect_to my_settings_data_path, alert: "No import source is configured."
      return
    end

    source.destroy
    redirect_to my_settings_data_path, notice: "Import source removed."
  end

  def sync_now
    source = current_user.heartbeat_import_source
    unless source
      redirect_to my_settings_data_path, alert: "No import source is configured."
      return
    end

    unless source.sync_enabled?
      redirect_to my_settings_data_path, alert: "Enable sync before running sync now."
      return
    end

    HeartbeatImportSourceSyncJob.perform_later(source.id)
    redirect_to my_settings_data_path, notice: "Sync queued."
  end

  private

  def ensure_current_user
    redirect_to root_path, alert: "You must be logged in to view this page." unless current_user
  end

  def create_params
    base_params.merge(provider: :wakatime_compatible)
  end

  def update_params
    base_params
  end

  def base_params
    params.require(:heartbeat_import_source).permit(
      :endpoint_url,
      :encrypted_api_key,
      :sync_enabled,
      :initial_backfill_start_date,
      :initial_backfill_end_date
    )
  end

  def source_payload(source)
    return nil unless source

    {
      id: source.id,
      provider: source.provider,
      endpoint_url: source.endpoint_url,
      sync_enabled: source.sync_enabled,
      status: source.status,
      initial_backfill_start_date: source.initial_backfill_start_date&.iso8601,
      initial_backfill_end_date: source.initial_backfill_end_date&.iso8601,
      backfill_cursor_date: source.backfill_cursor_date&.iso8601,
      last_synced_at: source.last_synced_at&.iso8601,
      last_synced_ago: source.last_synced_at ? view_context.time_ago_in_words(source.last_synced_at) : nil,
      last_error_message: source.last_error_message,
      last_error_at: source.last_error_at&.iso8601,
      consecutive_failures: source.consecutive_failures,
      imported_count: current_user.heartbeats.where(source_type: :wakapi_import).count
    }
  end
end
