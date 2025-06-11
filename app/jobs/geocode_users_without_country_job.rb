class GeocodeUsersWithoutCountryJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl

  enqueue_limit 1

  def perform
    return unless geocodable_users.present?

    GoodJob::Bulk.enqueue do
      geocodable_users.each do |user_id|
        SetUserCountryCodeJob.perform_later(user_id)
      end
    end
  end

  private

  def geocodable_users
    @geocodable_users ||= User.where(country_code: nil)
                              .joins(:heartbeats)
                              .where.not(heartbeats: { ip_address: nil })
                              .distinct
                              .pluck(:id)
  end
end
