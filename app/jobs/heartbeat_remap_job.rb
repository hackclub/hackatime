class HeartbeatRemapJob < ApplicationJob
  queue_as :default

  include ActiveJob::Continuable
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(total_limit: 1, key: "heartbeat_remap_job")
  retry_on(*HeartbeatRemapRunner::TRANSIENT_ERRORS, wait: 5.seconds, attempts: 5)

  def perform(run_id)
    run = HeartbeatRemapRun.find_by(id: run_id)
    return unless run

    step :process_batches, start: 0 do |step|
      loop do
        case run.reload.state
        when "queued", "running"
          HeartbeatRemapRunner.process_batch!(run)
        when "rolling_back"
          HeartbeatRemapRunner.rollback_batch!(run)
        else
          break
        end
        step.advance!
      end
    end
    HeartbeatRemapRunner.schedule_rollups!(run) if run.completed? || run.rolled_back?
  end
end
