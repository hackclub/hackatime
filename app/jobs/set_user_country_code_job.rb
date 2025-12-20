class SetUserCountryCodeJob < ApplicationJob
  include ApplicationHelper
  queue_as :literally_whenever

  def perform(user_id)
    @user_id = user_id
    ips = Heartbeat.where(user_id: user_id)
                   .where.not(ip_address: nil)
                   .distinct
                   .pluck(:ip_address)

    # Try IP geocoding first
    ips.each do |ip|
      country_code = geo(ip)
      next unless country_code.present?
      return user.update!(country_code: country_code)
    end

    # Fallback to timezone if IP geocoding failed
    return unless user.timezone.present?
    return if user.timezone == "UTC" # avoid anyone in the default timezone

    begin
      puts "Falling back to timezone-based country detection for timezone #{@user.timezone}"
      country_code = timezone_to_country(@user.timezone)

      if country_code.present?
        puts "Found country code from timezone: #{country_code}"
        user.update!(country_code: country_code)
      end
    rescue => e
      Rails.logger.error "timezone geocode fail for #{@user.timezone}: #{e.message}"
      Sentry.capture_exception(e)
    end
  end

  private

  def user
    @user ||= User.find(@user_id)
  end

  def timezone_to_country(timezone)
    ApplicationHelper.timezone_to_country(timezone)
  end

  def geo(ip)
    begin
      puts "Getting country code for IP #{ip}"
      result = Geocoder.search(ip).first
      return unless result&.country_code.present?

      result.country_code.upcase

    rescue => e
      Rails.logger.error "geocode fail on #{ip}: #{e.message}"
      Sentry.capture_exception(e)
    end
  end
end
