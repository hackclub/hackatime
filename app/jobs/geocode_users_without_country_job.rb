class GeocodeUsersWithoutCountryJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  include ApplicationHelper

  enqueue_limit 1

  BATCH_SIZE = 1000 # moving this higher can make stuff shaky, do it at your own risk!

  def perform
    User.where(country_code: nil)
        .joins(:heartbeats)
        .where.not(heartbeats: { ip_address: nil })
        .distinct
        .find_in_batches(batch_size: BATCH_SIZE) do |users|
      x(users)
    end
  end

  private

  def x(users)
    updates = {}

    users.each do |user|
      country_code = find(user)
      updates[user.id] = country_code if country_code.present?
    end

    return if updates.empty?

    User.upsert_all(
      updates.map { |id, code| { id: id, country_code: code } },
      unique_by: :id,
      update_only: [ :country_code ]
    )
  end

  def find(user)
    ip = Heartbeat.where(user_id: user.id)
                  .where.not(ip_address: nil)
                  .limit(10)
                  .pluck(:ip_address)
                  .uniq

    ip.each do |ip_address|
      country_code = geo(ip_address)
      return country_code if country_code.present?
    end

    tz_to_cc(user.timezone)
  end

  def geo(ip)
    result = Geocoder.search(ip).first
    return nil unless result&.country_code.present?
    result.country_code.upcase
  rescue => e
    Rails.logger.error "geocode fail on #{ip}: #{e.message}"
    Sentry.capture_exception(e)
    nil
  end

  def tz_to_cc(timezone)
    return nil if timezone.blank? || timezone == "UTC"

    tz = ActiveSupport::TimeZone[timezone]
    return nil unless tz&.tzinfo&.respond_to?(:country_code)
    tz.tzinfo.country_code&.upcase
  rescue => e
    Rails.logger.error "timezone geocode fail for #{timezone}: #{e.message}"
    Sentry.capture_exception(e)
    nil
  end
end
