class SetUserCountryCodeJob < ApplicationJob
  queue_as :literally_whenever

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    ips = user.heartbeats
              .where.not(ip_address: nil)
              .select(:ip_address)
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
