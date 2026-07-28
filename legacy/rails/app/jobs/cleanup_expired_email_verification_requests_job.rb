class CleanupExpiredEmailVerificationRequestsJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1
  )

  def perform
    EmailVerificationRequest.expired.update_all(deleted_at: Time.current)
  end
end
