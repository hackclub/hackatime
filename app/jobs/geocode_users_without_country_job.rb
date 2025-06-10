class GeocodeUsersWithoutCountryJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl

  enqueue_limit 1

  def perform
    return unless geocodable_users.exists?

    description = "Geocoding #{geocodable_users.count} user(s) at #{Time.current.iso8601}"

    GoodJob::Batch.enqueue(description: description) do
      geocodable_users.find_each do |user|
        SetUserCountryCodeJob.perform_later(user.id)
      end
    end
  end

  private

  def geocodable_users
    @geocodable_users ||= User.where(country_code: nil)
                              .joins(:heartbeats)
                              .where.not(heartbeats: { ip_address: nil })
                              .distinct
  end
end
