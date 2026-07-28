geoip2_database = Rails.root.join("db/geo/GeoLite2-City.mmdb")
require "geocoder/results/geoip2"
require "maxminddb"

class Geocoder::Lookup::SafeGeoip2 < Geocoder::Lookup::Base
  class << self
    def database(file)
      return @database if defined?(@database) && @database_file == file.to_s

      @database_file = file.to_s
      @database = MaxMindDB.new(@database_file)
    end
  end

  private

  def result_class
    Geocoder::Result::Geoip2
  end

  def results(query)
    file = Geocoder.config.geoip2[:file]
    return [] unless file.exist?

    result = self.class.database(file).lookup(query.to_s)
    result ? [ result ] : []
  rescue Errno::ENOENT
    []
  end
end

Geocoder::Lookup.ip_services = Geocoder::Lookup.ip_services + [ :safe_geoip2 ]

Geocoder.configure(
  timeout: 15,
  ip_lookup: :safe_geoip2,
  geoip2: {
    file: geoip2_database
  }
)
