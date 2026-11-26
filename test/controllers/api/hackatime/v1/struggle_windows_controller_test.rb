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

  def recent_window_start(offset_windows: 0)
    ((Time.current.to_i / 300) * 300) - 3600 + (offset_windows * 300)
  end

  def sign_window(
    user_id:,
    project_hash:,
    window_start_unix:,
    prev_chain_hash:,
    server_nonce:,
    raw_seconds: 300,
    credited_seconds: 300,
    struggle_points: 19.55,
    effective_multiplier: 1.0,
    effective_multiplier_milli: 1000,
    git_head_sha: "1111111111111111111111111111111111111111"
  )
    digest = StruggleChainVerifier.compute_digest(
      prev_chain_hash: prev_chain_hash,
      server_nonce: server_nonce,
      user_id: user_id.to_s,
      project_hash: project_hash,
      window_start_unix: window_start_unix,
      raw_seconds: raw_seconds,
      credited_seconds: credited_seconds,
      effective_multiplier_milli: effective_multiplier_milli,
      provenance_mask: 3,
      git_head_sha: git_head_sha
    )
    sig = @keypair.sign(nil, digest)
    {
      user_id: user_id.to_s,
      project_hash: project_hash,
      project_name: "raytracer",
      window_start_unix: window_start_unix,
      raw_seconds: raw_seconds,
      credited_seconds: credited_seconds,
      struggle_points: struggle_points,
      diversity_multiplier: 1.15,
      verify_multiplier: 1.0,
      effective_multiplier: effective_multiplier,
      effective_multiplier_milli: effective_multiplier_milli,
      provenance_mask: 3,
      primary_language: "C++",
      ai_harness: "antigravity",
      persisted_diff_lines: 18,
      signal_counts: { "SIG_ARCH_STEER" => 1, "SIG_VERIFY_EXEC" => 1 },
      signal_breakdown: [
        { signal_code: "SIG_ARCH_STEER", trigger_count: 1, raw_points: 4.0, awarded_points: 4.0, provenance_mask: 2, gate_status: "awarded" },
        { signal_code: "SIG_VERIFY_EXEC", trigger_count: 1, raw_points: 3.0, awarded_points: 3.0, provenance_mask: 1, gate_status: "awarded" }
      ],
      git_head_sha: git_head_sha,
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
      window_start_unix: recent_window_start(offset_windows: 0),
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: boot["server_nonce"]
    )
    w2 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: recent_window_start(offset_windows: 1),
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

  test "accepts idempotent retry of an already-committed batch after a lost HTTP response" do
    @user.update!(ed25519_public_key: @keypair.raw_public_key)
    nonce = StruggleNonceStore.issue(user_id: @user.id)
    project_hash = "1" * 64
    t1 = recent_window_start(offset_windows: 0)

    w1 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: nonce
    )
    w2 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1 + 300,
      prev_chain_hash: w1[:chain_hash_hex],
      server_nonce: nonce
    )

    assert_difference("StruggleWindow.count", 2) do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ w1, w2 ].to_json,
        headers: auth_headers
    end
    assert_response :ok

    # Simulate client losing the HTTP response and replaying the exact same batch
    # (even if the original nonce already expired from memory)
    StruggleNonceStore.clear!
    assert_no_difference("StruggleWindow.count") do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ w1, w2 ].to_json,
        headers: auth_headers
    end
    assert_response :ok
    retry_body = JSON.parse(response.body)
    assert_equal 2, retry_body["accepted"]
    assert_match(/\A[0-9a-f]{32}\z/, retry_body["next_server_nonce"])

    # Client can also retry [w1, w2] together with a newly appended w3 chained off w2
    w3 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1 + 600,
      prev_chain_hash: w2[:chain_hash_hex],
      server_nonce: retry_body["next_server_nonce"]
    )
    assert_difference("StruggleWindow.count", 1) do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ w1, w2, w3 ].to_json,
        headers: auth_headers
    end
    assert_response :ok
    assert_equal 3, @user.struggle_windows.where(project_hash: project_hash).count
  end

  test "keeps saved chain history immutable and rejects older or overwritten windows even with a fresh nonce" do
    @user.update!(ed25519_public_key: @keypair.raw_public_key)
    nonce1 = StruggleNonceStore.issue(user_id: @user.id)
    project_hash = "2" * 64
    t1 = recent_window_start(offset_windows: 2)

    w1 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: nonce1
    )
    post "/api/hackatime/v1/users/current/struggle_windows",
      params: [ w1 ].to_json,
      headers: auth_headers
    assert_response :ok
    saved_window = @user.struggle_windows.find_by!(project_hash: project_hash)
    fresh_nonce = JSON.parse(response.body)["next_server_nonce"]

    # Attempt 1: insert a new window older than the current tip using a fresh nonce
    older = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1 - 300,
      prev_chain_hash: w1[:chain_hash_hex],
      server_nonce: fresh_nonce
    )
    assert_no_difference("StruggleWindow.count") do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ older ].to_json,
        headers: auth_headers
    end
    assert_response :forbidden

    # Attempt 2: overwrite the existing saved timestamp with different signed fields
    rewrite = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1,
      prev_chain_hash: w1[:chain_hash_hex],
      server_nonce: fresh_nonce,
      raw_seconds: 240,
      credited_seconds: 240,
      git_head_sha: "2222222222222222222222222222222222222222"
    )
    assert_no_difference("StruggleWindow.count") do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ rewrite ].to_json,
        headers: auth_headers
    end
    assert_response :forbidden
    assert_equal 300, saved_window.reload.raw_seconds
    assert_equal "1111111111111111111111111111111111111111", saved_window.git_head_sha
  end

  test "rejects backdated and future-dated windows even when signed with a fresh server_nonce" do
    @user.update!(ed25519_public_key: @keypair.raw_public_key)
    fresh_nonce = StruggleNonceStore.issue(user_id: @user.id)

    backdated = sign_window(
      user_id: @user.id,
      project_hash: "3" * 64,
      window_start_unix: 8.days.ago.to_i,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: fresh_nonce
    )
    assert_no_difference("StruggleWindow.count") do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ backdated ].to_json,
        headers: auth_headers
    end
    assert_response :forbidden

    future_dated = sign_window(
      user_id: @user.id,
      project_hash: "4" * 64,
      window_start_unix: 1.hour.from_now.to_i,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: fresh_nonce
    )
    assert_no_difference("StruggleWindow.count") do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ future_dated ].to_json,
        headers: auth_headers
    end
    assert_response :forbidden
  end

  test "rejects windows whose credited_seconds exceed raw_seconds or struggle_points rules" do
    @user.update!(ed25519_public_key: @keypair.raw_public_key)
    nonce = StruggleNonceStore.issue(user_id: @user.id)

    excess_credit = sign_window(
      user_id: @user.id,
      project_hash: "5" * 64,
      window_start_unix: recent_window_start(offset_windows: 0),
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: nonce,
      raw_seconds: 1,
      credited_seconds: 300,
      struggle_points: 0.0,
      effective_multiplier: 1.0,
      effective_multiplier_milli: 1000
    )
    assert_no_difference("StruggleWindow.count") do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ excess_credit ].to_json,
        headers: auth_headers
    end
    assert_response :bad_request

    below_threshold = sign_window(
      user_id: @user.id,
      project_hash: "6" * 64,
      window_start_unix: recent_window_start(offset_windows: 0),
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: nonce,
      raw_seconds: 300,
      credited_seconds: 45,
      struggle_points: 1.5,
      effective_multiplier: 0.15,
      effective_multiplier_milli: 150
    )
    assert_no_difference("StruggleWindow.count") do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ below_threshold ].to_json,
        headers: auth_headers
    end
    assert_response :bad_request

    # Confirm PostgreSQL CHECK constraints enforce credit invariants even if validations are bypassed
    valid_window = sign_window(
      user_id: @user.id,
      project_hash: "7" * 64,
      window_start_unix: recent_window_start(offset_windows: 0),
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: nonce
    )
    post "/api/hackatime/v1/users/current/struggle_windows",
      params: [ valid_window ].to_json,
      headers: auth_headers
    assert_response :ok

    saved = @user.struggle_windows.find_by!(project_hash: "7" * 64)
    assert_raises(ActiveRecord::StatementInvalid) do
      saved.update_columns(raw_seconds: 1, convertible_seconds: 300)
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      saved.update_columns(struggle_points: 1.0, convertible_seconds: 30)
    end
  end

  test "rejects forged offline server_nonce and rolls back entire batch atomically" do
    @user.update!(ed25519_public_key: @keypair.raw_public_key)
    valid_nonce = StruggleNonceStore.issue(user_id: @user.id)
    project_hash = "c" * 64
    t1 = recent_window_start(offset_windows: 0)

    w1 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: valid_nonce
    )
    w2_forged = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1 + 300,
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
      window_start_unix: recent_window_start(offset_windows: 0),
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

  test "accepts offline chained continuation windows within 7 days after server cache restart" do
    @user.update!(ed25519_public_key: @keypair.raw_public_key)
    nonce1 = StruggleNonceStore.issue(user_id: @user.id)
    project_hash = "e" * 64
    t1 = (Time.current.to_i / 300) * 300 - 900

    w1 = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: nonce1
    )
    post "/api/hackatime/v1/users/current/struggle_windows",
      params: [ w1 ].to_json,
      headers: auth_headers
    assert_response :ok
    nonce2 = JSON.parse(response.body)["next_server_nonce"]

    # Simulate server restart wiping ephemeral nonce cache while client works offline
    StruggleNonceStore.clear!

    w2_offline = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1 + 300,
      prev_chain_hash: w1[:chain_hash_hex],
      server_nonce: nonce2
    )
    w3_offline = sign_window(
      user_id: @user.id,
      project_hash: project_hash,
      window_start_unix: t1 + 600,
      prev_chain_hash: w2_offline[:chain_hash_hex],
      server_nonce: nonce2
    )

    assert_difference("StruggleWindow.count", 2) do
      post "/api/hackatime/v1/users/current/struggle_windows",
        params: [ w2_offline, w3_offline ].to_json,
        headers: auth_headers
    end
    assert_response :ok
  end
end
