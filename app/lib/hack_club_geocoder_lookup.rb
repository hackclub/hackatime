require "geocoder/lookups/base"
require "geocoder/results/base"

class HackClubGeocoderResult < Geocoder::Result::Base
  def coordinates
    [ @data["lat"], @data["lng"] ]
  end

  def latitude
    @data["lat"]
  end

  def longitude
    @data["lng"]
  end

  def country_code
    @data["country_code"]
  end

  def country
    @data["country_name"]
  end

  def city
    @data["city"]
  end

  def state
    @data["region"]
  end

  def postal_code
    @data["postal_code"]
  end

  def address
    @data["formatted_address"]
  end
end

class HackClubGeocoderLookup < Geocoder::Lookup::Base
  def name
    :hack_club
  end

  def required_api_key_parts
    [ "api_key" ]
  end

  def supported_protocols
    [ :http, :https ]
  end

  def configuration
    Geocoder.config
  end

  private

  def base_query_url(query)
    if query.ip_address?
      "https://geocoder.hackclub.com/v1/geoip?"
    else
      "https://geocoder.hackclub.com/v1/geocode?"
    end
  end

  def query_url_params(query)
    if query.ip_address?
      { ip: query.sanitized_text, key: Geocoder.config[:api_key] }
    else
      { address: query.sanitized_text, key: Geocoder.config[:api_key] }
    end
  end

  def results(query)
    return [] unless doc = fetch_data(query)
    return [] if doc.is_a?(Hash) && doc.has_key?("error")

    [ HackClubGeocoderResult.new(doc) ]
  end

  def fetch_data(query)
    response = super(query)
    return response unless response.is_a?(String)

    JSON.parse(response)
  rescue JSON::ParserError => e
    Geocoder.log(:warn, "Invalid JSON response from Hack Club Geocoder: #{e.message}")
    {}
  end
end
