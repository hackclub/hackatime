# Primitives shared with the desktop client. desktop/PROTOCOL.md is the
# specification; the Swift implementation lives in
# desktop/macos/Sources/HackatimeDesktopCore and both sides test the same
# vectors.
module Evidence
  module Crypto
    ZERO_HASH = ("0" * 64).freeze
    CHAIN_DOMAIN = "hkt-chain-v1\n".b.freeze
    TIMELAPSE_DOMAIN = "hkt-timelapse-v1\n".b.freeze
    REQUIRED_DOMAIN = "hkt-required-v1\n".b.freeze
    COMMIT_DOMAIN = "hkt-beacon-secret-v1\n".b.freeze
    DEVICE_SECRET_DOMAIN = "hkt-device-secret-v1\n".b.freeze
    SPOT_CHECK_DOMAIN = "hkt-spot-check-v1\n".b.freeze
    FRAME_AAD = "hkt-frame-v1".b.freeze
    HEX64 = /\A\h{64}\z/

    module_function

    def sha256(bytes) = OpenSSL::Digest::SHA256.digest(bytes)
    def sha256_hex(bytes) = OpenSSL::Digest::SHA256.hexdigest(bytes)
    def unhex(hex) = [ hex ].pack("H*")

    # hash = H(domain || prev || beacon_value || H(payload_bytes))
    def chain_hash(prev_hex, beacon_value_hex, payload_bytes)
      sha256_hex(CHAIN_DOMAIN + unhex(prev_hex) + unhex(beacon_value_hex) + sha256(payload_bytes.b))
    end

    def beacon_commitment(secret_hex) = sha256_hex(COMMIT_DOMAIN + unhex(secret_hex))

    # Server-paced timelapse: the seconds of a minute its frames are due, one
    # every `interval` seconds. Only the beacon decides where they start, so
    # the client cannot choose when it is watched or prepare footage ahead of
    # time.
    def timelapse_seconds(beacon_value_hex, device_uid, interval)
      first = sha256(TIMELAPSE_DOMAIN + unhex(beacon_value_hex) + device_uid.b).getbyte(0) % interval
      first.step(59, interval).to_a
    end

    # Each device gets its own secret for every beacon minute, so a ship
    # that reveals one device's secret says nothing about another device.
    def device_secret(beacon_secret_hex, device_uid)
      OpenSSL::HMAC.hexdigest("SHA256", unhex(beacon_secret_hex), DEVICE_SECRET_DOMAIN + device_uid.b)
    end

    # Which timelapse frames must be revealed at ship. Decided by a device
    # secret that only the commitment of was public while the user worked.
    def required_frame?(secret_hex, frame_hash_hex, ratio)
      sha256(REQUIRED_DOMAIN + unhex(secret_hex) + unhex(frame_hash_hex)).getbyte(0) < (256 * ratio).round
    end

    # Which committed working tree snapshots are spot-checked, beyond the
    # first and last of a ship. Fixed per block, so no draft can re-roll it.
    def spot_check?(secret_hex, tree_root_hex, ratio)
      sha256(SPOT_CHECK_DOMAIN + unhex(secret_hex) + unhex(tree_root_hex)).getbyte(0) < (256 * ratio).round
    end

    # Salted Merkle tree over a working tree: one leaf per file, sorted by path.
    def merkle_leaf(salt_hex, path, content)
      sha256_hex("\x00".b + unhex(salt_hex) + path.b + "\x00".b + sha256(content.b))
    end

    def merkle_root(leaf_hexes)
      return ZERO_HASH if leaf_hexes.empty?

      level = leaf_hexes.map { |hex| unhex(hex) }
      while level.length > 1
        level = level.each_slice(2).map { |left, right| right ? sha256("\x01".b + left + right) : left }
      end
      level.first.unpack1("H*")
    end

    # ChaCha20-Poly1305 (RFC 8439) from OpenSSL; the client uses CryptoKit's
    # ChaChaPoly, whose sealed-box layout is the same:
    #   blob = nonce(12) || ciphertext || tag(16)
    # Every 5-minute segment has its own random key and holds a few dozen
    # frames, so random 96-bit nonces are far inside their safety margin.
    # No primitive here is hand-written.
    def aead_open(key, blob, aad: FRAME_AAD)
      raise ArgumentError, "ciphertext too short" if blob.bytesize < 28

      cipher = OpenSSL::Cipher.new("chacha20-poly1305").decrypt
      cipher.key = key
      cipher.iv = blob.byteslice(0, 12)
      cipher.auth_tag = blob.byteslice(-16, 16)
      cipher.auth_data = aad
      cipher.update(blob.byteslice(12, blob.bytesize - 28)) + cipher.final
    end

    def aead_seal(key, plaintext, nonce: SecureRandom.random_bytes(12), aad: FRAME_AAD)
      cipher = OpenSSL::Cipher.new("chacha20-poly1305").encrypt
      cipher.key = key
      cipher.iv = nonce
      cipher.auth_data = aad
      nonce + cipher.update(plaintext) + cipher.final + cipher.auth_tag
    end
  end
end
