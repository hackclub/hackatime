class HeartbeatImportRemoteDownloadJob < ApplicationJob
  queue_as :default

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1, key: -> { "heartbeat_import_remote_download_job_#{arguments.first}" }
  )

  retry_on HeartbeatImportDumpClient::TransientError,
    wait: ->(executions) { (executions**2).seconds + rand(1..4).seconds },
    attempts: 8 do |job, error|
      HeartbeatImportRunner.fail_run_for_error!(import_run_id: job.arguments.first, error:)
    end

  def perform(import_run_id, download_url, exported_at = nil)
    run = HeartbeatImportRun.find_by(id: import_run_id)
    return if run.nil? || run.terminal?

    client = HeartbeatImportDumpClient.new(source_kind: run.source_kind, api_key: run.encrypted_api_key)
    file_content = client.download_dump(download_url)
    if run.wakatime_dump?
      import_context = {
        user_agents_by_id: client.list_user_agents.index_by { |ua| ua[:id] },
        machine_names_by_id: client.list_machine_names.to_h { |machine| [ machine[:id], machine[:value] ] },
        recent_heartbeats: recent_heartbeats(client, run:, exported_at:)
      }
    end
    file_path = HeartbeatImportRunner.persist_remote_download(run:, file_content:, import_context:)

    HeartbeatImportJob.perform_later(run.id, file_path)
  rescue HeartbeatImportDumpClient::AuthenticationError, HeartbeatImportDumpClient::RequestError => e
    return unless run
    HeartbeatImportRunner.fail_run!(
      run, message: HeartbeatImportRunner.failure_message_for(run:, error: e),
      remote_dump_status: run.remote_dump_status.presence || "failed"
    )
  end

  private

  # A reused export ends when it was created. Days are in the user's WakaTime timezone, so pad by a day.
  def recent_heartbeats(client, run:, exported_at:)
    exported_on = Time.zone.parse(exported_at.to_s)&.to_date || (run.remote_requested_at || run.created_at).to_date
    ((exported_on - 1.day)..(Date.current + 1.day)).flat_map { |date| client.list_heartbeats(date) }
  end
end
