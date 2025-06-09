class CleanupExpiredEmailVerificationRequestsJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    drop: true
  )

  def perform
    # Soft delete all expired and non-deleted verification requests in a single query
    EmailVerificationRequest.expired.where(deleted_at: nil)
                            .update_all(deleted_at: Time.current)
  end
end
