class HeartbeatImportDumpJob < ApplicationJob
  queue_as :latency_10s

  POLL_INTERVAL = 3.seconds
  MAX_POLL_DURATION = 30.minutes

  retry_on HeartbeatImportDumpClient::TransientError,
    wait: ->(executions) { (executions**2).seconds + rand(1..4).seconds },
    attempts: 8 do |job, error|
      HeartbeatImportRunner.fail_run_for_error!(
        import_run_id: job.arguments.first,
        error:
      )
    end

  def perform(import_run_id)
    run = HeartbeatImportRun.includes(:user).find_by(id: import_run_id)
    return unless runnable?(run)

    client = HeartbeatImportDumpClient.new(source_kind: run.source_kind, api_key: run.encrypted_api_key)
    process_dump!(run, current_dump_for(run, client))
  rescue HeartbeatImportDumpClient::ManualDownloadLinkRequiredError => e
    handle_manual_download_link_required!(run, e.message)
  rescue HeartbeatImportDumpClient::AuthenticationError => e
    fail_run!(run, e)
  rescue HeartbeatImportDumpClient::RequestError => e
    fail_run!(run, e)
  end

  private

  def runnable?(run)
    return false unless run&.remote?
    return false if run.terminal?

    return true if Flipper.enabled?(:imports, run.user)

    fail_run!(run, "Imports are no longer enabled for this user.")
    false
  end

  def current_dump_for(run, client)
    return request_dump!(run, client) if run.remote_dump_id.blank?

    fetch_dump!(run, client)
  end

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

    dump
  end

  def fetch_dump!(run, client)
    dump = client.list_dumps.find { |item| item[:id] == run.remote_dump_id.to_s }
    raise HeartbeatImportDumpClient::RequestError, "Data dump #{run.remote_dump_id} was not found." if dump.blank?

    dump
  end

  def process_dump!(run, dump)
    if dump_failed?(dump)
      fail_run!(run, "The remote provider could not finish preparing the data dump.")
      return
    end

    if dump_ready_for_download?(dump)
      queue_download!(run, dump)
      return
    end

    mark_waiting!(run, dump)

    if poll_timed_out?(run)
      fail_run!(run, "Data dump did not complete within #{(MAX_POLL_DURATION / 60).to_i} minutes.")
      return
    end

    schedule_poll(run)
  end

  def poll_timed_out?(run)
    requested_at = run.remote_requested_at || run.started_at || run.created_at
    requested_at <= MAX_POLL_DURATION.ago
  end

  def dump_failed?(dump)
    dump[:has_failed] || dump[:is_stuck]
  end

  def dump_ready_for_download?(dump)
    !dump[:is_processing] && dump[:download_url].present?
  end

  def queue_download!(run, dump)
    HeartbeatImportRunner.queue_remote_download(
      run:,
      download_url: dump[:download_url],
      remote_dump_status: dump[:status],
      remote_percent_complete: dump[:percent_complete].positive? ? dump[:percent_complete] : 100.0
    )
  end

  def mark_waiting!(run, dump)
    run.update!(
      state: :waiting_for_dump,
      remote_dump_status: dump[:status],
      remote_percent_complete: dump[:percent_complete],
      message: waiting_message(dump),
      error_message: nil
    )
  end

  def schedule_poll(run)
    self.class.set(wait: POLL_INTERVAL).perform_later(run.id)
  end

  def waiting_message(dump)
    status = dump[:status].presence || "Preparing data dump"
    percent = dump[:percent_complete].to_f
    return "#{status}..." unless percent.positive?

    "#{status} (#{percent.round}%)"
  end

  def fail_run!(run, error)
    HeartbeatImportRunner.fail_run!(
      run,
      message: HeartbeatImportRunner.failure_message_for(run:, error:),
      remote_dump_status: run.remote_dump_status.presence || "failed"
    )
  end

  def handle_manual_download_link_required!(run, message)
    recipient_email = HeartbeatImportRunner.recipient_email_for(run.user)

    if recipient_email.present?
      HeartbeatImportMailer.wakatime_manual_download_required(
        run.user,
        recipient_email:
      ).deliver_now
      HeartbeatImportRunner.fail_run!(
        run,
        message: "WakaTime needs a recent export download link. Check your email for the next step.",
        notify: false,
        remote_dump_status: run.remote_dump_status.presence || "failed"
      )
    else
      HeartbeatImportRunner.fail_run!(
        run,
        message: "#{message} Add an email address to your account, then try again.",
        remote_dump_status: run.remote_dump_status.presence || "failed"
      )
    end
  end
end
