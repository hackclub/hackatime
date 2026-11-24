require "test_helper"
require "base64"
require "openssl"

class Api::Hackatime::V1::StruggleWindowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    StruggleNonceStore.clear!
    @user = create(:user)
    @api_key = create(:api_key, user: @user, name: "hackatime-ai")
    @keypair = OpenSSL::PKey.generate_key("ED25519")
    @pub_hex = @keypair.raw_public_key.unpack1("H*")
  end

  teardown do
    StruggleNonceStore.clear!
  end

  def auth_headers(basic: false)
    token = basic ? "Basic #{Base64.strict_encode64(@api_key.token)}" : "Bearer #{@api_key.token}"
    {
      "Authorization" => token,
      "Content-Type" => "application/json"
    }
  end

  def sign_window(user_id:, project_hash:, window_start_unix:, prev_chain_hash:, server_nonce:, credited_seconds: 300)
    digest = StruggleChainVerifier.compute_digest(
      prev_chain_hash: prev_chain_hash,
      server_nonce: server_nonce,
      user_id: user_id.to_s,
      project_hash: project_hash,
      window_start_unix: window_start_unix,
      raw_seconds: 300,
      credited_seconds: credited_seconds,
      effective_multiplier_milli: 1000,
      provenance_mask: 3,
      git_head_sha: "1111111111111111111111111111111111111111"
    )
    sig = @keypair.sign(nil, digest)
    {
      user_id: user_id.to_s,
      project_hash: project_hash,
      project_name: "raytracer",
      window_start_unix: window_start_unix,
      raw_seconds: 300,
      credited_seconds: credited_seconds,
      struggle_points: 19.55,
      diversity_multiplier: 1.15,
      verify_multiplier: 1.0,
      effective_multiplier: 1.0,
      effective_multiplier_milli: 1000,
      provenance_mask: 3,
      primary_language: "C++",
      ai_harness: "antigravity",
      persisted_diff_lines: 18,
      signal_counts: { "SIG_ARCH_STEER" => 1, "SIG_VERIFY_EXEC" => 1 },
      signal_breakdown: [
        { signal_code: "SIG_ARCH_STEER", trigger_count: 1, raw_points: 4.0, awarded_points: 4.0, provenance_mask: 2, gate_status: "awarded" },
        { signal_code: "SIG_VERIFY_EXEC", trigger_count: 1, raw_points: 3.0, awarded_points: 3.0, provenance_mask: 1, gate_status: "awarded" }
      ],
      git_head_sha: "1111111111111111111111111111111111111111",
      prev_chain_hash: prev_chain_hash,
      server_nonce: server_nonce,
      chain_hash_hex: digest.unpack1("H*"),
      ed25519_sig_hex: sig.unpack1("H*")
    }
  end

  test "registers Ed25519 key, issues ephemeral nonce, and ingests chained Struggle Windows via Basic auth" do
    put "/api/hackatime/v1/users/current/ed25519_key",
      params: { ed25519_public_key_hex: @pub_hex }.to_json,
      headers: auth_headers(basic: true)
    assert_response :ok
    assert_equal @keypair.raw_public_key.b, @user.reload.ed25519_public_key.b

    get "/api/hackatime/v1/users/current/struggle_nonce", headers: auth_headers(basic: true)
    assert_response :ok
    boot = JSON.parse(response.body)
    assert_equal @user.id.to_s, boot["user_id"]
    assert_match(/\A[0-9a-f]{32}\z/, boot["server_nonce"])

    project_hash = "b" * 64
    w1 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: 1_795_089_600,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: boot["server_nonce"]
    )
    w2 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: 1_795_089_900,
      prev_chain_hash: w1[:chain_hash_hex],
      server_nonce: boot["server_nonce"]
    )

    assert_difference("StruggleWindow.count", 2) do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ w1, w2 ].to_json,
        headers: auth_headers(basic: true)
    end
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal 2, body["accepted"]
    assert_match(/\A[0-9a-f]{32}\z/, body["next_server_nonce"])

    # Option A: ingested windows start unconverted until user converts on /my/struggle
    ingested = @user.struggle_windows.order(:window_start)
    assert_equal [ 0, 0 ], ingested.pluck(:credited_seconds)
    assert_equal [ 300, 300 ], ingested.pluck(:convertible_seconds)
    assert_equal [ nil, nil ], ingested.pluck(:converted_at)
    assert_equal [ 18, 18 ], ingested.pluck(:persisted_diff_lines)

    # PostgreSQL SP Earning Ledger records exact per-signal breakdown rows atomically
    assert_equal 4, @user.struggle_point_events.count
    assert_equal %w[SIG_ARCH_STEER SIG_VERIFY_EXEC],
      @user.struggle_point_events.distinct.order(:signal_code).pluck(:signal_code)
  end

  test "rejects forged offline server_nonce and rolls back entire batch atomically" do
    @user.update!(ed25519_public_key: @keypair.raw_public_key)
    valid_nonce = StruggleNonceStore.issue(user_id: @user.id)
    project_hash = "c" * 64

    w1 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: 1_795_089_600,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: valid_nonce
    )
    w2_forged = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: 1_795_089_900,
      prev_chain_hash: w1[:chain_hash_hex],
      server_nonce: "deadbeefdeadbeefdeadbeefdeadbeef"
    )

    assert_no_difference("StruggleWindow.count") do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ w1, w2_forged ].to_json,
        headers: auth_headers
    end
    assert_response :forbidden
  end

  test "rejects tampered Ed25519 signature" do
    @user.update!(ed25519_public_key: @keypair.raw_public_key)
    nonce = StruggleNonceStore.issue(user_id: @user.id)
    tampered = sign_window(
      user_id: @user.id,
      project_hash: "d" * 64,
      window_start_unix: 1_795_089_600,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: nonce
    ).merge(credited_seconds: 299)

    assert_no_difference("StruggleWindow.count") do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ tampered ].to_json,
        headers: auth_headers
    end
    assert_response :forbidden
  end
end
