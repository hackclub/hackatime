class AttemptToDeliverPhysicalMailJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  enqueue_limit 1

  def perform
    PhysicalMail.pending_delivery.find_each do |mail|
      mail.deliver!
    end
  end
end
