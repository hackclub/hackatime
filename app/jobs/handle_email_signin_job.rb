class HandleEmailSigninJob < ApplicationJob
  queue_as :latency_critical

  # Keep the class loadable while jobs queued before the HCA cutover drain.
  def perform(*) = nil
end
