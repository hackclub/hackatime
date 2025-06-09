class SetUserCountryCodeJob < ApplicationJob
  queue_as :literally_whenever

  def perform(user_id)
    ips = Heartbeat.where(user_id: user_id)
                   .where.not(ip_address: nil)
                   .distinct
                   .pluck(:ip_address)
    return if ips.empty?

    ips.each do |ip|
      begin
        puts "Getting country code for IP #{ip}"
        result = Geocoder.search(ip).first
        next unless result&.country_code.present?

        country_code = result.country_code.upcase
        puts "Found country code: #{country_code}"

        if ISO3166::Country.codes.include?(country_code)
          user.update!(country_code: country_code)
          return
        end
      rescue => e
        Rails.logger.error "Error getting country code for IP #{ip}: #{e.message}"
        next
      end
    end
  end
end
