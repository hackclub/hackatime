# pagy did a massive update, reworked a bunch of shit, but ahoy-captain is still using the old API
# this is a fuck ass workaround to update the version of pagy but not make ahoy-captain crash and burn builds
# https://github.com/ddnexus/pagy/releases/tag/v43.0.0

class Pagy
  module Frontend
    # null
  end
  Backend = Method unless const_defined?(:Backend)
end
