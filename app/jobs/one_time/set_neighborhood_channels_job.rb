class OneTime::SetNeighborhoodChannelsJob < ApplicationJob
  queue_as :default

  def perform
    User.where.not(slack_uid: nil).find_each(batch_size: 100) do |user|
      user.set_neighborhood_channel
      user.save! if user.changed?
    end
  end
end
