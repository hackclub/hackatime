class HeartbeatImportJob < ApplicationJob
  queue_as :default

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "heartbeat_import_job_#{arguments.first}" },
    drop: true
  )

  def perform(import_run_id, file_path)
    HeartbeatImportRunner.run_import(import_run_id:, file_path:)
  end
end
