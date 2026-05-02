class HeartbeatImportRemoteDownloadJob < ApplicationJob
  queue_as :default

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "heartbeat_import_remote_download_job_#{arguments.first}" },
    drop: true
  )

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
    import_context = if run.wakatime_dump?
      { user_agents_by_id: client.list_user_agents.index_by { |user_agent| user_agent[:id] } }
    end
    file_path = HeartbeatImportRunner.persist_remote_download(run:, file_content:, import_context:)

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
