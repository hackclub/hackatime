class UpdateSlackNeighborhoodChannelsJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  enqueue_limit

  def perform
    User.where.not(slack_uid: nil).find_each(batch_size: 1000) do |user|
      user.set_neighborhood_channel
      user.save! if user.changed?
    end
  end
end
