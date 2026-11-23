require "test_helper"

class VerifyAuditSubmissionJobTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @project_hash = "f" * 64
    @commit_sha = "abcdef1234567890abcdef1234567890abcdef12"
  end

  test "verifies intact chain, remote Commit corroboration, and flags excessive Tier-C share" do
    Commit.create!(sha: @commit_sha, user: @user)

    w1 = @user.struggle_windows.create!(
      project_hash: @project_hash,
      project_name: "robot-firmware",
      window_start: Time.at(1_795_091_000).utc,
      raw_seconds: 300,
      convertible_seconds: 300,
      credited_seconds: 300,
      converted_at: Time.current,
      struggle_points: 19.0,
      diversity_multiplier: 1.15,
      verify_multiplier: 1.0,
      effective_multiplier: 1.0,
      effective_multiplier_milli: 1000,
      provenance_mask: 3,
      primary_language: "C++",
      ai_harness: "antigravity",
      signal_counts: { "SIG_ERROR_LOOP" => 1, "SIG_VERIFY_EXEC" => 1 },
      git_head_sha: @commit_sha,
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: "0" * 32,
      chain_hash: "a" * 64,
      signature: "s" * 64
    )

    @user.struggle_windows.create!(
      project_hash: @project_hash,
      project_name: "robot-firmware",
      window_start: Time.at(1_795_091_300).utc,
      raw_seconds: 300,
      convertible_seconds: 300,
      credited_seconds: 300,
      converted_at: Time.current,
      struggle_points: 12.0,
      diversity_multiplier: 1.0,
      verify_multiplier: 1.0,
      effective_multiplier: 1.0,
      effective_multiplier_milli: 1000,
      provenance_mask: 5, # Tier A + Tier C -> 50% plugin share (> 30% threshold)
      primary_language: "C++",
      ai_harness: "godot",
      signal_counts: { "SIG_VERIFY_EXEC" => 1 },
      git_head_sha: @commit_sha,
      prev_chain_hash: w1.chain_hash,
      server_nonce: "0" * 32,
      chain_hash: "b" * 64,
      signature: "s" * 64
    )

    submission = @user.audit_submissions.create!(
      project_hash: @project_hash,
      project_name: "robot-firmware",
      program_slug: "ysws-hardware",
      bundle_sha256: "9" * 64,
      submitted_hours: 0.17
    )

    VerifyAuditSubmissionJob.perform_now(submission.id)
    submission.reload

    assert submission.chain_verified
    assert submission.git_push_verified
    assert_in_delta 50.0, submission.plugin_share_pct.to_f, 0.01
    codes = submission.anomaly_flags.map { |f| f["code"] }
    assert_includes codes, "excessive_tier_c_plugin_share"
    refute_includes codes, "broken_hash_chain"
  end
end
