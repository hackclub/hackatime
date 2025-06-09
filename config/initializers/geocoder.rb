require Rails.root.join("app/lib/hack_club_geocoder_lookup")

# Ensure the lookup class is available in the Geocoder::Lookup namespace
Geocoder::Lookup.const_set(:HackClub, HackClubGeocoderLookup) unless Geocoder::Lookup.const_defined?(:HackClub)

Geocoder.configure(
  timeout: 15,
  lookup: HackClubGeocoderLookup,
  api_key: ENV["HACKCLUB_GEOCODER_API_KEY"],
  cache: Geocoder::CacheStore::Generic.new(Rails.cache, {}),
)
