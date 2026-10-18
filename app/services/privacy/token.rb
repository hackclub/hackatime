module Privacy
  class Token
    JWKS_URL = "https://yeet.hackclub.com/.well-known/jwks.json"
    AUDIENCE = "hackatime"
    LOCK = Mutex.new

    def self.verify(token, action:)
      raise Error.new("invalid_token", 401) unless token.is_a?(String) && token.bytesize.between?(1, 16_384)

      _, header = JWT.decode(token, nil, false)
      unless header["alg"] == "ES256" && header["typ"] == "JWT" && header["kid"].is_a?(String) && header["kid"].present?
        raise Error.new("invalid_token", 401)
      end

      key = public_key(header["kid"])
      claims, = JWT.decode(token, key, true,
        algorithms: [ "ES256" ], verify_iss: true, iss: "hackclub-privacy",
        verify_aud: true, aud: AUDIENCE, verify_iat: false, verify_expiration: true, leeway: 30,
        required_claims: %w[iss aud iat exp jti request_id action dry_run subject])
      validate_claims!(claims)
      raise Error.new("action_mismatch", 400) unless claims["action"] == action
      claims
    rescue JWT::DecodeError, JSON::ParserError, ArgumentError, OpenSSL::PKey::PKeyError
      raise Error.new("invalid_token", 401)
    end

    def self.validate_claims!(claims)
      now = Time.now.to_i
      iat, exp = claims.values_at("iat", "exp")
      subject = claims["subject"]
      valid = claims["aud"] == AUDIENCE &&
        iat.is_a?(Integer) && exp.is_a?(Integer) &&
        iat <= now + 30 && iat >= now - 330 && exp >= iat && exp - iat <= 300 &&
        claims["jti"].is_a?(String) && claims["jti"].present? &&
        claims["request_id"].is_a?(String) && claims["request_id"].present? &&
        [ true, false ].include?(claims["dry_run"]) &&
        claims["action"].is_a?(String) && claims["action"].present? && subject.is_a?(Hash) &&
        subject["emails"].is_a?(Array) && subject["emails"].all? { |email| email.is_a?(String) && email.present? } &&
        %w[slack_id identity_id].all? { |field| subject[field].nil? || (subject[field].is_a?(String) && subject[field].present?) }
      raise Error.new("invalid_token", 401) unless valid
    end

    def self.public_key(kid)
      LOCK.synchronize do
        url = ENV.fetch("PRIVACY_JWKS_URL", JWKS_URL)
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        expired = @url != url || !@fetched_at || now - @fetched_at >= 300
        unknown = !@keys&.key?(kid) && (!@attempted_at || now - @attempted_at >= 30)
        if expired || unknown
          @attempted_at = now
          begin
            response = HTTP.timeout(connect: 2, read: 3, write: 2).get(url)
            raise Error.new("jwks_unavailable", 503) unless response.status.success?
            jwks = JSON.parse(response.body.to_s)
            unless jwks.is_a?(Hash) && jwks["keys"].is_a?(Array) && jwks["keys"].all? { |key| key.is_a?(Hash) }
              raise Error.new("jwks_unavailable", 503)
            end
            keys = jwks.fetch("keys").select { |key| key["kty"] == "EC" && key["crv"] == "P-256" && key["kid"].present? && (!key["use"] || key["use"] == "sig") && (!key["alg"] || key["alg"] == "ES256") }
            @keys = keys.to_h { |key| [ key.fetch("kid"), JWT::JWK.import(key).public_key ] }
            @url, @fetched_at = url, now
          rescue HTTP::Error, JSON::ParserError, KeyError, TypeError, ArgumentError, OpenSSL::PKey::PKeyError
            raise Error.new("jwks_unavailable", 503)
          end
        end
        @keys.fetch(kid) { raise Error.new("invalid_token", 401) }
      end
    end
  end
end
