class HeartbeatImportDumpJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  POLL_INTERVAL = 30.seconds

  retry_on HeartbeatImportDumpClient::TransientError,
    wait: ->(executions) { (executions**2).seconds + rand(1..4).seconds },
    attempts: 8

  good_job_control_concurrency_with(
    key: -> { "heartbeat_import_dump_job_#{arguments.first}" },
    total_limit: 1
  )

  def perform(import_run_id)
    run = HeartbeatImportRun.includes(:user).find_by(id: import_run_id)
    return unless run&.remote?
    return if run.terminal?

    unless Flipper.enabled?(:imports, run.user)
      fail_run!(run, "Imports are no longer enabled for this user.")
      return
    end

    client = HeartbeatImportDumpClient.new(source_kind: run.source_kind, api_key: run.encrypted_api_key)

    if run.remote_dump_id.blank?
      request_dump!(run, client)
      return
    end

    sync_dump!(run, client)
  rescue HeartbeatImportDumpClient::AuthenticationError => e
    fail_run!(run, e.message)
  rescue HeartbeatImportDumpClient::RequestError => e
    fail_run!(run, e.message)
  end

  private

  def request_dump!(run, client)
    run.update!(
      state: :requesting_dump,
      started_at: run.started_at || Time.current,
      message: "Requesting data dump...",
      error_message: nil
    )

    dump = client.request_dump
    run.update!(
      state: :waiting_for_dump,
      remote_dump_id: dump[:id],
      remote_dump_status: dump[:status],
      remote_percent_complete: dump[:percent_complete],
      remote_requested_at: Time.current,
      message: waiting_message(dump),
      error_message: nil
    )

    enqueue_poll(run)
  end

  def sync_dump!(run, client)
    dump = client.list_dumps.find { |item| item[:id] == run.remote_dump_id.to_s }
    raise HeartbeatImportDumpClient::RequestError, "Data dump #{run.remote_dump_id} was not found." if dump.blank?

    if dump[:has_failed] || dump[:is_stuck]
      fail_run!(run, "The remote provider could not finish preparing the data dump.")
      return
    end

    if dump[:is_processing] || dump[:download_url].blank?
      run.update!(
        state: :waiting_for_dump,
        remote_dump_status: dump[:status],
        remote_percent_complete: dump[:percent_complete],
        message: waiting_message(dump),
        error_message: nil
      )
      enqueue_poll(run)
      return
    end

    run.update!(
      state: :downloading_dump,
      remote_dump_status: dump[:status],
      remote_percent_complete: dump[:percent_complete].positive? ? dump[:percent_complete] : 100.0,
      message: "Downloading data dump...",
      error_message: nil
    )

    file_content = client.download_dump(dump[:download_url])
    file_path = HeartbeatImportRunner.persist_remote_download(run:, file_content:)

    HeartbeatImportJob.perform_later(run.id, file_path)
  end

  def enqueue_poll(run)
    self.class.set(wait: POLL_INTERVAL).perform_later(run.id)
  end

  def waiting_message(dump)
    status = dump[:status].presence || "Preparing data dump"
    percent = dump[:percent_complete].to_f
    return "#{status}..." unless percent.positive?

    "#{status} (#{percent.round}%)"
  end

  def fail_run!(run, message)
    run.update!(
      state: :failed,
      remote_dump_status: run.remote_dump_status.presence || "failed",
      message: "Import failed: #{message}",
      error_message: message,
      finished_at: Time.current
    )
    run.clear_sensitive_fields!
  end
end
