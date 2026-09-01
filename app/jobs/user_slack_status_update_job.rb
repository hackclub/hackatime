class UserSlackStatusUpdateJob < ApplicationJob
  queue_as :latency_10s

  def perform(user_id)
    User.find_by(id: user_id)&.update_slack_status
  end
end
