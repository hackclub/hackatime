class SlackActivityDigestSchedulerJob < ApplicationJob
  queue_as :literally_whenever

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: "slack_activity_digest_scheduler"
  )

  def perform(reference_time = Time.current)
    SlackActivityDigestSubscription.enabled.find_each do |subscription|
      next unless subscription.due_for_delivery?(reference_time)

      SlackActivityDigestJob.perform_later(subscription.id, reference_time.to_i)
    end
  end
end
