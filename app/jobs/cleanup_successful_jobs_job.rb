class CleanupSuccessfulJobsJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  enqueue_limit

  def perform
    GoodJob.cleanup_preserved_jobs(older_than: 2.days, include_discarded: false)
  end
end
