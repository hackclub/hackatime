module HasEnqueueControl
  extend ActiveSupport::Concern
  include GoodJob::ActiveJobExtensions::Concurrency

  class_methods do
    def enqueue_limit(limit = 1)
      good_job_control_concurrency_with(
        total_limit: limit,
        key: "enqueue_control_#{self.name.underscore}",
        drop: true
      )
    end
  end

  def perform(*args)
    super
  rescue GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError
    msg = "Concurrency limit exceeded for #{self.class.name}"
    msg += " with args: #{args.inspect}" if args.present?
    Rails.logger.info msg
  end
end
