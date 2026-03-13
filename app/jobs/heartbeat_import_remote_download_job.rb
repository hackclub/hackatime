class HeartbeatImportRemoteDownloadJob < ApplicationJob
  queue_as :default

  retry_on HeartbeatImportDumpClient::TransientError,
    wait: ->(executions) { (executions**2).seconds + rand(1..4).seconds },
    attempts: 8 do |job, error|
      HeartbeatImportRunner.fail_run_for_error!(
        import_run_id: job.arguments.first,
        error:
      )
    end

  def perform(import_run_id, download_url)
    run = HeartbeatImportRun.find_by(id: import_run_id)
    return unless run
    return if run.terminal?

    client = HeartbeatImportDumpClient.new(
      source_kind: run.source_kind,
      api_key: run.encrypted_api_key
    )

    file_content = client.download_dump(download_url)
    file_path = HeartbeatImportRunner.persist_remote_download(run:, file_content:)

    HeartbeatImportJob.perform_later(run.id, file_path)
  rescue HeartbeatImportDumpClient::AuthenticationError, HeartbeatImportDumpClient::RequestError => e
    return unless run

    HeartbeatImportRunner.fail_run!(
      run,
      message: HeartbeatImportRunner.failure_message_for(run:, error: e),
      remote_dump_status: run.remote_dump_status.presence || "failed"
    )
  end
end
