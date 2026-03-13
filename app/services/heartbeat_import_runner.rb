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
      super("Remote imports are limited to once every 4 hours.")
    end
  end

  class FeatureDisabledError < StandardError; end
  class InvalidProviderError < StandardError; end

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

  def self.find_run(user:, import_id:)
    user.heartbeat_import_runs.find_by(id: import_id)
  end

  def self.latest_run(user:)
    HeartbeatImportRun.latest_for(user)
  end

  def self.refresh_remote_run!(run)
    return run unless run&.remote?
    return run unless run.active_import?
    return run unless Flipper.enabled?(:imports, run.user)
    return run if run.updated_at > REMOTE_REFRESH_THROTTLE.ago

    if inline_good_job_execution?
      HeartbeatImportDumpJob.perform_now(run.id)
    else
      HeartbeatImportDumpJob.perform_later(run.id)
    end

    run.reload
  rescue => e
    Rails.logger.error("Error refreshing heartbeat import run #{run&.id}: #{e.message}")
    run
  end

  def self.remote_import_cooldown_until(user:)
    HeartbeatImportRun.remote_cooldown_until_for(user)
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
      cooldown_until: run.cooldown_until&.iso8601,
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
        reset_sailors_log!(user) if run.remote?
      else
        run.update!(
          state: :failed,
          imported_count: result[:imported_count],
          skipped_count: result[:skipped_count],
          errors_count: result[:errors].size,
          message: "Import failed: #{result[:error]}",
          error_message: result[:error],
          finished_at: Time.current
        )
      end
    end
  rescue => e
    HeartbeatImportRun.find_by(id: import_run_id)&.update!(
      state: :failed,
      message: "Import failed: #{e.message}",
      error_message: e.message,
      finished_at: Time.current
    )
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

  def self.build_success_message(result)
    message = "Imported #{result[:imported_count]} out of #{result[:total_count]} heartbeats in #{result[:time_taken]}s."
    return message if result[:skipped_count].zero?

    "#{message} Skipped #{result[:skipped_count]} duplicate heartbeats."
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

  def self.inline_good_job_execution?
    Rails.env.development? && Rails.application.config.good_job.execution_mode == :inline
  end
end
