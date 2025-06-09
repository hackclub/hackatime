class HackClubGeocoderService
  BASE_URL = "https://geocoder.hackclub.com"

  def self.geoip(ip_address)
    new.geoip(ip_address)
  end

  def self.geocode(address)
    new.geocode(address)
  end

  def initialize
    @api_key = ENV["HACKCLUB_GEOCODER_API_KEY"]
    raise "HACKCLUB_GEOCODER_API_KEY environment variable not set" if @api_key.blank?
  end

  def geoip(ip_address)
    return nil if ip_address.blank?

    url = "#{BASE_URL}/v1/geoip"
    params = { ip: ip_address, key: @api_key }

    make_request(url, params)
  end

  def geocode(address)
    return nil if address.blank?

    url = "#{BASE_URL}/v1/geocode"
    params = { address: address, key: @api_key }

    make_request(url, params)
  end

  private

  def make_request(url, params)
    uri = URI(url)
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.error "HackClub Geocoder API error: #{response.code} #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "HackClub Geocoder API request failed: #{e.message}"
    nil
  end
end
