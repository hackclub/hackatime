Geocoder.configure(
  timeout: 15,
  ip_lookup: :geoip2,
  geoip2: {
    file: Rails.root.join("db/geo/GeoLite2-City.mmdb")
  }
)
