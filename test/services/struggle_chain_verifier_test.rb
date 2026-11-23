require "test_helper"

class StruggleChainVerifierTest < ActiveSupport::TestCase
  # Golden cryptographic test vector generated directly by C++20 hackatime-d (libsodium)
  # using deterministic seed 0x01..0x20 and Scenario A (300s, M=1.000, TierA|TierB=3).
  CPP_GOLDEN_PUB_HEX = "79b5562e8fe654f94078b112e8a98ba7901f853ae695bed7e0e3910bad049664".freeze
  CPP_GOLDEN_CHAIN_HEX = "303418b048d7b39116047d11e76516b0d22764edf8e32751847099fd8b729226".freeze
  CPP_GOLDEN_SIG_HEX = "bee71b0edfa2b014c3bc05c632547ed78e4ad9f630c846dca46fb9e1b6d6e62d37e2fa289d4b16124b70e69cafbc61f15923b98e9c7efb158ae68e84cf2dd802".freeze

  def golden_params
    {
      user_id: "42",
      project_hash: "a" * 64,
      window_start_unix: 1_795_089_600,
      raw_seconds: 300,
      credited_seconds: 300,
      effective_multiplier_milli: 1000,
      provenance_mask: 3,
      git_head_sha: "0123456789abcdef0123456789abcdef01234567",
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: "0123456789abcdef0123456789abcdef",
      chain_hash_hex: CPP_GOLDEN_CHAIN_HEX,
      ed25519_sig_hex: CPP_GOLDEN_SIG_HEX
    }
  end

  test "verifies bit-exact C++20 libsodium Ed25519 signature and SHA-256 chain hash" do
    raw_pub = StruggleChainVerifier.decode_hex_exact(CPP_GOLDEN_PUB_HEX, 32)
    assert StruggleChainVerifier.valid?(
      window_params: golden_params,
      expected_prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      raw_public_key: raw_pub
    )
  end

  test "rejects tampered credited_seconds" do
    raw_pub = StruggleChainVerifier.decode_hex_exact(CPP_GOLDEN_PUB_HEX, 32)
    refute StruggleChainVerifier.valid?(
      window_params: golden_params.merge(credited_seconds: 299),
      expected_prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      raw_public_key: raw_pub
    )
  end

  test "rejects forged server_nonce" do
    raw_pub = StruggleChainVerifier.decode_hex_exact(CPP_GOLDEN_PUB_HEX, 32)
    refute StruggleChainVerifier.valid?(
      window_params: golden_params.merge(server_nonce: "f" * 32),
      expected_prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      raw_public_key: raw_pub
    )
  end

  test "rejects broken prev_chain_hash linkage" do
    raw_pub = StruggleChainVerifier.decode_hex_exact(CPP_GOLDEN_PUB_HEX, 32)
    refute StruggleChainVerifier.valid?(
      window_params: golden_params,
      expected_prev_chain_hash: "f" * 64,
      raw_public_key: raw_pub
    )
  end

  test "rejects flipped bit in Ed25519 signature" do
    raw_pub = StruggleChainVerifier.decode_hex_exact(CPP_GOLDEN_PUB_HEX, 32)
    bad_sig = CPP_GOLDEN_SIG_HEX.dup
    bad_sig[0] = bad_sig[0] == "a" ? "b" : "a"
    refute StruggleChainVerifier.valid?(
      window_params: golden_params.merge(ed25519_sig_hex: bad_sig),
      expected_prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      raw_public_key: raw_pub
    )
  end
end
