class SetUserCountryCodeJob < ApplicationJob
  include ApplicationHelper
  queue_as :literally_whenever

  def perform(user_id)
    ips = Heartbeat.where(user_id: user_id)
                   .where.not(ip_address: nil)
                   .distinct
                   .pluck(:ip_address)

    # Try IP geocoding first
    ips.each do |ip|
      begin
        puts "Getting country code for IP #{ip}"
        result = Geocoder.search(ip).first
        next unless result&.country_code.present?

        country_code = result.country_code.upcase
        puts "Found country code: #{country_code}"

        if ISO3166::Country.codes.include?(country_code)
          User.find(user_id).update!(country_code: country_code)
          return
        end
      rescue => e
        Rails.logger.error "Error getting country code for IP #{ip}: #{e.message}"
        next
      end
    end

    # Fallback to timezone if IP geocoding failed
    user = User.find(user_id)
    return unless user.timezone.present?
    return if user.timezone == "UTC" # avoid anyone in the default timezone

    begin
      puts "Falling back to timezone-based country detection for timezone #{user.timezone}"
      country_code = timezone_to_country(user.timezone)

      if country_code.present? && ISO3166::Country.codes.include?(country_code.upcase)
        country_code = country_code.upcase
        puts "Found country code from timezone: #{country_code}"
        user.update!(country_code: country_code)
      end
    rescue => e
      Rails.logger.error "Error getting country code from timezone #{user.timezone}: #{e.message}"
    end
  end
end
