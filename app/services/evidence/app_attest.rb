# Verifies an Apple App Attest attestation (macOS 27+, full signed app with
# the App Attest entitlement). Follows Apple's "Validating apps that connect
# to your server" steps: certificate chain to Apple's root, nonce extension,
# key ID, RP ID hash, zero counter and AAGUID. A pass upgrades the device to
# the `app_attest` tier; a failure only means no bonus.
module Evidence
  class AppAttest
    class Invalid < StandardError; end

    ROOT_CA_PATH = Rails.root.join("config/evidence/apple_app_attestation_root_ca.pem")
    NONCE_OID = "1.2.840.113635.100.8.2"
    AAGUIDS = { "appattest\x00\x00\x00\x00\x00\x00\x00".b => :production, "appattestdevelop".b => :development }.freeze

    def self.app_id = ENV.fetch("DESKTOP_APP_ATTEST_APP_ID", "") # "TEAMID.com.hackclub.hackatime.desktop"

    # Returns the attested P-256 public key (DER, base64).
    def self.verify!(attestation_b64:, key_id_b64:, client_data:, app_id: self.app_id, allow_development: !Rails.env.production?)
      raise Invalid, "App Attest is not configured" if app_id.blank?

      object = Cbor.decode(Base64.decode64(attestation_b64))
      raise Invalid, "not an App Attest statement" unless object["fmt"] == "apple-appattest"

      certs = Array(object.dig("attStmt", "x5c")).map { |der| OpenSSL::X509::Certificate.new(der) }
      raise Invalid, "missing certificates" if certs.length < 2

      store = OpenSSL::X509::Store.new
      store.add_cert(OpenSSL::X509::Certificate.new(File.read(ROOT_CA_PATH)))
      raise Invalid, "certificate chain does not reach Apple's root" unless store.verify(certs[0], certs[1..])

      auth_data = object.fetch("authData")
      nonce = OpenSSL::Digest::SHA256.digest(auth_data + OpenSSL::Digest::SHA256.digest(client_data))
      extension = certs[0].extensions.find { |ext| ext.oid == NONCE_OID }
      raise Invalid, "missing nonce extension" unless extension
      # SEQUENCE { [1] { OCTET STRING nonce } }
      embedded = OpenSSL::ASN1.decode(OpenSSL::ASN1.decode(extension.to_der).value.last.value).value.first.value.first.value
      raise Invalid, "nonce mismatch" unless ActiveSupport::SecurityUtils.secure_compare(embedded, nonce)

      public_point = certs[0].public_key.public_key.to_octet_string(:uncompressed)
      key_id = Base64.decode64(key_id_b64)
      raise Invalid, "key ID mismatch" unless OpenSSL::Digest::SHA256.digest(public_point) == key_id

      raise Invalid, "RP ID mismatch" unless auth_data.byteslice(0, 32) == OpenSSL::Digest::SHA256.digest(app_id)
      raise Invalid, "counter must be zero" unless auth_data.byteslice(33, 4).unpack1("N").zero?

      environment = AAGUIDS[auth_data.byteslice(37, 16)]
      raise Invalid, "unexpected AAGUID" if environment.nil? || (environment == :development && !allow_development)

      credential_length = auth_data.byteslice(53, 2).unpack1("n")
      raise Invalid, "credential ID mismatch" unless auth_data.byteslice(55, credential_length) == key_id

      Base64.strict_encode64(certs[0].public_key.to_der)
    rescue Cbor::Error, OpenSSL::OpenSSLError, KeyError, NoMethodError, TypeError => e
      raise Invalid, "malformed attestation: #{e.message}"
    end

    # Minimal CBOR decoder for the attestation object (maps, arrays, byte and
    # text strings, unsigned and negative integers).
    module Cbor
      class Error < StandardError; end

      module_function

      def decode(bytes)
        value, offset = read(bytes.b, 0)
        raise Error, "trailing bytes" unless offset == bytes.bytesize

        value
      end

      def read(bytes, offset)
        raise Error, "truncated" if offset >= bytes.bytesize

        initial = bytes.getbyte(offset)
        major, info = initial >> 5, initial & 0x1f
        length, offset = read_length(bytes, info, offset + 1)
        case major
        when 0 then [ length, offset ]
        when 1 then [ -1 - length, offset ]
        when 2, 3
          raise Error, "truncated" if offset + length > bytes.bytesize

          string = bytes.byteslice(offset, length)
          [ major == 3 ? string.force_encoding(Encoding::UTF_8) : string, offset + length ]
        when 4
          Array.new(length) { value, offset = read(bytes, offset); value }.then { |array| [ array, offset ] }
        when 5
          hash = {}
          length.times do
            key, offset = read(bytes, offset)
            hash[key], offset = read(bytes, offset)
          end
          [ hash, offset ]
        else raise Error, "unsupported major type #{major}"
        end
      end

      def read_length(bytes, info, offset)
        case info
        when 0..23 then [ info, offset ]
        when 24 then [ bytes.getbyte(offset), offset + 1 ]
        when 25 then [ bytes.byteslice(offset, 2).unpack1("n"), offset + 2 ]
        when 26 then [ bytes.byteslice(offset, 4).unpack1("N"), offset + 4 ]
        when 27 then [ bytes.byteslice(offset, 8).unpack1("Q>"), offset + 8 ]
        else raise Error, "indefinite lengths are not supported"
        end
      end
    end
  end
end
