require "fileutils"
require "stringio"
require "zlib"

class HeartbeatImportRunner
  PROGRESS_INTERVAL = 250
  REMOTE_REFRESH_THROTTLE = 5.seconds
  TMP_DIR = Rails.root.join("tmp", "heartbeat_imports")

  class ActiveImportError < StandardError; end
  class CooldownError < StandardError
    attr_reader :retry_at

    def initialize(retry_at)
      @retry_at = retry_at
      super("Remote imports are limited to once every 8 minutes.")
    end
  end

  class FeatureDisabledError < StandardError; end
  class InvalidProviderError < StandardError; end
  class InvalidDownloadUrlError < StandardError; end

  def self.start_dev_upload(user:, uploaded_file:)
    ensure_no_active_import!(user)

    run = user.heartbeat_import_runs.create!(
      source_kind: :dev_upload,
      source_filename: uploaded_file.original_filename.to_s,
      state: :queued,
      message: "Queued import."
    )

    file_path = persist_uploaded_file(uploaded_file, run.id)
    HeartbeatImportJob.perform_later(run.id, file_path)
    run
  end

  def self.start_remote_import(user:, provider:, api_key:)
    ensure_imports_enabled!(user)
    ensure_no_active_import!(user)
    ensure_remote_cooldown!(user)

    run = user.heartbeat_import_runs.create!(
      source_kind: normalize_provider(provider),
      state: :queued,
      encrypted_api_key: api_key.to_s,
      message: "Queued import."
    )

    HeartbeatImportDumpJob.perform_later(run.id)
    run
  end

  def self.start_wakatime_download_link_import(user:, download_url:)
    ensure_imports_enabled!(user)
    ensure_no_active_import!(user)

    unless HeartbeatImportDumpClient.valid_wakatime_download_url?(download_url)
      raise InvalidDownloadUrlError, "Download link must start with https://wakatime.s3.amazonaws.com."
    end

    run = user.heartbeat_import_runs.create!(
      source_kind: :wakatime_download_link,
      state: :queued,
      message: "Queued import."
    )

    queue_remote_download(run:, download_url:, remote_dump_status: "Manual download link received")
    run
  end

  def self.find_run(user:, import_id:)
    user.heartbeat_import_runs.find_by(id: import_id)
  end

  def self.latest_run(user:)
    HeartbeatImportRun.latest_for(user)
  end

  def self.refresh_remote_run!(run)
    return run unless refreshable_remote_run?(run)

    HeartbeatImportDumpJob.perform_later(run.id)

    run.reload
  rescue => e
    Rails.logger.error("Error refreshing heartbeat import run #{run&.id}: #{e.message}")
    run
  end

  def self.remote_import_cooldown_until(user:)
    return nil if user.admin_level_superadmin?

    HeartbeatImportRun.remote_cooldown_until_for(user)
  end

  def self.refreshable_remote_run?(run)
    run&.remote? &&
      run.remote_dump_pollable? &&
      Flipper.enabled?(:imports, run.user) &&
      run.updated_at <= REMOTE_REFRESH_THROTTLE.ago &&
      run.encrypted_api_key.present?
  end

  def self.serialize(run)
    return nil unless run

    {
      import_id: run.id.to_s,
      state: run.state,
      source_kind: run.source_kind,
      progress_percent: run.progress_percent,
      processed_count: run.processed_count,
      total_count: run.total_count,
      imported_count: run.imported_count,
      skipped_count: run.skipped_count,
      errors_count: run.errors_count,
      message: run.message.to_s,
      error_message: run.error_message,
      remote_dump_status: run.remote_dump_status,
      remote_percent_complete: run.remote_percent_complete,
      cooldown_until: remote_import_cooldown_until(user: run.user)&.iso8601,
      source_filename: run.source_filename,
      updated_at: run.updated_at.iso8601,
      started_at: run.started_at&.iso8601,
      finished_at: run.finished_at&.iso8601
    }
  end

  def self.run_import(import_run_id:, file_path:)
    ActiveRecord::Base.connection_pool.with_connection do
      run = HeartbeatImportRun.includes(:user).find_by(id: import_run_id)
      return unless run
      return if run.terminal?

      user = run.user
      file_content = decode_file_content(File.binread(file_path)).force_encoding("UTF-8")

      run.update!(
        state: :importing,
        total_count: nil,
        processed_count: 0,
        started_at: run.started_at || Time.current,
        message: "Importing heartbeats..."
      )

      result = HeartbeatImportService.import_from_file(
        file_content,
        user,
        progress_interval: PROGRESS_INTERVAL,
        on_progress: lambda { |processed_count|
          run.update_columns(
            processed_count: processed_count,
            message: "Importing heartbeats...",
            updated_at: Time.current
          )
        }
      )

      if result[:success]
        complete_run!(run, result:)
      else
        fail_run!(
          run,
          message: result[:error],
          imported_count: result[:imported_count],
          skipped_count: result[:skipped_count],
          errors_count: result[:errors].size
        )
      end
    end
  rescue => e
    run = HeartbeatImportRun.includes(:user).find_by(id: import_run_id)
    fail_run!(run, message: e.message) if run
  ensure
    FileUtils.rm_f(file_path) if file_path.present?
    HeartbeatImportRun.find_by(id: import_run_id)&.clear_sensitive_fields!
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  def self.persist_uploaded_file(uploaded_file, import_run_id)
    FileUtils.mkdir_p(TMP_DIR)
    ext = File.extname(uploaded_file.original_filename.to_s)
    ext = ".json" if ext.blank?
    file_path = TMP_DIR.join("#{import_run_id}#{ext}")
    FileUtils.cp(uploaded_file.tempfile.path, file_path)

    file_path.to_s
  end

  def self.persist_remote_download(run:, file_content:)
    FileUtils.mkdir_p(TMP_DIR)

    file_path = TMP_DIR.join("#{run.id}-remote.json")
    File.binwrite(file_path, decode_file_content(file_content))
    file_path.to_s
  end

  def self.queue_remote_download(run:, download_url:, remote_dump_status: nil, remote_percent_complete: nil)
    run.update!(
      state: :downloading_dump,
      remote_dump_status: remote_dump_status || run.remote_dump_status,
      remote_percent_complete: remote_percent_complete.nil? ? run.remote_percent_complete : remote_percent_complete,
      message: "Downloading data dump...",
      error_message: nil
    )

    HeartbeatImportRemoteDownloadJob.perform_later(run.id, download_url)
  end

  def self.build_success_message(result)
    message = "Imported #{result[:imported_count]} out of #{result[:total_count]} heartbeats in #{result[:time_taken]}s."
    return message if result[:skipped_count].zero?

    "#{message} Skipped #{result[:skipped_count]} duplicate heartbeats."
  end

  def self.complete_run!(run, result:)
    run.update!(
      state: :completed,
      processed_count: result[:total_count],
      total_count: result[:total_count],
      imported_count: result[:imported_count],
      skipped_count: result[:skipped_count],
      errors_count: result[:errors].size,
      message: build_success_message(result),
      error_message: nil,
      finished_at: Time.current
    )

    reset_sailors_log!(run.user) unless run.dev_upload?
    send_completion_email(run)
  end

  def self.fail_run!(
    run,
    message:,
    imported_count: run.imported_count,
    skipped_count: run.skipped_count,
    errors_count: run.errors_count,
    remote_dump_status: run.remote_dump_status.presence || "failed",
    notify: true
  )
    run.update!(
      state: :failed,
      imported_count:,
      skipped_count:,
      errors_count:,
      remote_dump_status: run.remote? ? remote_dump_status : run.remote_dump_status,
      message: "Import failed: #{message}",
      error_message: message,
      finished_at: Time.current
    )

    send_failure_email(run) if notify
    run.clear_sensitive_fields!
  end

  def self.fail_run_for_error!(import_run_id:, error:, notify: true)
    run = HeartbeatImportRun.includes(:user).find_by(id: import_run_id)
    return unless run
    return if run.terminal?

    fail_run!(run, message: failure_message_for(run:, error:), notify:)
  end

  def self.failure_message_for(run:, error:)
    case error
    when HeartbeatImportDumpClient::AuthenticationError
      "#{import_source_name(run)} rejected the import because the API key is invalid."
    when HeartbeatImportDumpClient::TransientError
      transient_failure_message_for(run:, error:)
    else
      error.respond_to?(:message) ? error.message : error.to_s
    end
  end

  def self.import_source_name(run)
    run.hackatime_v1_dump? ? "Hackatime v1" : "WakaTime"
  end

  def self.ensure_imports_enabled!(user)
    return if Flipper.enabled?(:imports, user)

    raise FeatureDisabledError, "Imports are not enabled for this user."
  end

  def self.ensure_no_active_import!(user)
    return unless HeartbeatImportRun.active_for(user)

    raise ActiveImportError, "Another import is already in progress."
  end

  def self.ensure_remote_cooldown!(user)
    retry_at = remote_import_cooldown_until(user:)
    return if retry_at.blank?

    raise CooldownError, retry_at
  end

  def self.normalize_provider(provider)
    normalized_provider = provider.to_s

    aliases = {
      "wakatime" => "wakatime_dump",
      "hackatime_v1" => "hackatime_v1_dump",
      "wakatime_dump" => "wakatime_dump",
      "hackatime_v1_dump" => "hackatime_v1_dump"
    }

    aliases.fetch(normalized_provider) { raise InvalidProviderError, "Unsupported import provider." }
  end

  def self.decode_file_content(file_content)
    return file_content unless file_content&.bytes&.first(2) == [ 0x1f, 0x8b ]

    gz_reader = Zlib::GzipReader.new(StringIO.new(file_content))
    gz_reader.read
  ensure
    gz_reader&.close
  end

  def self.reset_sailors_log!(user)
    return unless user.sailors_log.present?

    user.sailors_log.update!(projects_summary: {})
    user.sailors_log.send(:initialize_projects_summary)
  end

  def self.transient_failure_message_for(run:, error:)
    return provider_error_message_for(run) if error.status.to_i >= 500

    "#{import_source_name(run)} could not be reached while processing the import. Please try again."
  end

  def self.provider_error_message_for(run)
    message = "#{import_source_name(run)} ran into an error while processing the import."
    return message unless run.hackatime_v1_dump?

    "#{message} Please reach out to #hackatime-help on Slack."
  end

  def self.send_completion_email(run)
    return unless send_import_email?(run)

    recipient_email = recipient_email_for(run.user)
    return if recipient_email.blank?

    HeartbeatImportMailer.import_completed(
      run.user,
      run:,
      recipient_email:
    ).deliver_now
  rescue => e
    Rails.logger.error("Failed to send heartbeat import completion email for run #{run.id}: #{e.message}")
  end

  def self.send_failure_email(run)
    return unless send_import_email?(run)

    recipient_email = recipient_email_for(run.user)
    return if recipient_email.blank?

    HeartbeatImportMailer.import_failed(
      run.user,
      run:,
      recipient_email:
    ).deliver_now
  rescue => e
    Rails.logger.error("Failed to send heartbeat import failure email for run #{run.id}: #{e.message}")
  end

  def self.send_import_email?(run)
    !run.dev_upload?
  end

  def self.recipient_email_for(user)
    user.email_addresses.order(:id).pick(:email)
  end
end
