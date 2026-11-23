require "digest"
require "openssl"

# Verifies Struggle Telemetry Protocol (STP v1) tamper-evident hash chains and
# Ed25519 signatures produced by hackatime-d using Ruby stdlib OpenSSL (zero extra gems).
#
# Wire framing matches shared/protocol_v1.json bit-for-bit:
#   len_u32_le + bytes("HACKATIME_STP_V1")
#   len_u32_le + bytes(prev_chain_hash)
#   len_u32_le + bytes(server_nonce)
#   len_u32_le + bytes(user_id)
#   len_u32_le + bytes(project_hash)
#   int64_le(window_start_unix)
#   uint16_le(raw_seconds)
#   uint16_le(credited_seconds)
#   uint16_le(effective_multiplier_milli)
#   uint8(provenance_mask)
#   len_u32_le + bytes(git_head_sha)
class StruggleChainVerifier
  PROTOCOL_DOMAIN = "HACKATIME_STP_V1".freeze
  ED25519_PUBLIC_KEY_BYTES = 32
  ED25519_SIGNATURE_BYTES = 64

  def self.compute_digest(
    prev_chain_hash:,
    server_nonce:,
    user_id:,
    project_hash:,
    window_start_unix:,
    raw_seconds:,
    credited_seconds:,
    effective_multiplier_milli:,
    provenance_mask:,
    git_head_sha:
  )
    sha = Digest::SHA256.new
    feed_len_prefixed(sha, PROTOCOL_DOMAIN)
    feed_len_prefixed(sha, prev_chain_hash.to_s)
    feed_len_prefixed(sha, server_nonce.to_s)
    feed_len_prefixed(sha, user_id.to_s)
    feed_len_prefixed(sha, project_hash.to_s)
    sha.update([ window_start_unix.to_i ].pack("q<"))
    sha.update([ raw_seconds.to_i ].pack("S<"))
    sha.update([ credited_seconds.to_i ].pack("S<"))
    sha.update([ effective_multiplier_milli.to_i ].pack("S<"))
    sha.update([ provenance_mask.to_i ].pack("C"))
    feed_len_prefixed(sha, git_head_sha.to_s)
    sha.digest
  end

  def self.valid_public_key?(raw_public_key)
    return false unless raw_public_key.is_a?(String) && raw_public_key.bytesize == ED25519_PUBLIC_KEY_BYTES

    OpenSSL::PKey.new_raw_public_key("ED25519", raw_public_key)
    true
  rescue OpenSSL::PKey::PKeyError
    false
  end

  def self.decode_hex_exact(hex, expected_bytes)
    return nil unless hex.is_a?(String) && hex.match?(/\A[0-9a-fA-F]{#{expected_bytes * 2}}\z/)

    [ hex ].pack("H*")
  end

  def self.valid?(window_params:, expected_prev_chain_hash:, raw_public_key:)
    return false unless valid_public_key?(raw_public_key)
    return false unless window_params[:prev_chain_hash].to_s == expected_prev_chain_hash.to_s

    claimed_digest = decode_hex_exact(window_params[:chain_hash_hex].to_s, 32)
    signature_bytes = decode_hex_exact(window_params[:ed25519_sig_hex].to_s, ED25519_SIGNATURE_BYTES)
    return false unless claimed_digest && signature_bytes

    expected_digest = compute_digest(
      prev_chain_hash: expected_prev_chain_hash,
      server_nonce: window_params[:server_nonce],
      user_id: window_params[:user_id],
      project_hash: window_params[:project_hash],
      window_start_unix: window_params[:window_start_unix],
      raw_seconds: window_params[:raw_seconds],
      credited_seconds: window_params[:credited_seconds],
      effective_multiplier_milli: window_params[:effective_multiplier_milli],
      provenance_mask: window_params[:provenance_mask],
      git_head_sha: window_params[:git_head_sha]
    )

    return false unless OpenSSL.fixed_length_secure_compare(expected_digest, claimed_digest)

    pkey = OpenSSL::PKey.new_raw_public_key("ED25519", raw_public_key)
    pkey.verify(nil, signature_bytes, expected_digest)
  rescue OpenSSL::PKey::PKeyError, ArgumentError
    false
  end

  def self.feed_len_prefixed(sha, value)
    bytes = value.b
    sha.update([ bytes.bytesize ].pack("L<"))
    sha.update(bytes) unless bytes.empty?
  end
  private_class_method :feed_len_prefixed
end
