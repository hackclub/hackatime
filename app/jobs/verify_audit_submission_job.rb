# Runs Layer 1 (chain linkage), Layer 2 (authoritative GitHub/GitLab commit DAG & surviving diff check),
# Layer 3 (Fraud Squad behavioral pattern analysis across the SP ledger),
# and Layer 4 (unpredictable stratified audit sampling via AuditSamplingService).
class VerifyAuditSubmissionJob < ApplicationJob
  queue_as :default

  def perform(audit_submission_id)
    submission = AuditSubmission.find_by(id: audit_submission_id)
    return unless submission

    windows = submission.project_windows.to_a
    events = StrugglePointEvent.where(user_id: submission.user_id, project_hash: submission.project_hash)
    flags = []

    # Layer 1: Verify cryptographic hash-chain continuity across all project windows
    chain_ok = windows.any?
    prev_hash = StruggleWindow::GENESIS_CHAIN_HASH
    windows.each do |w|
      if w.prev_chain_hash != prev_hash
        chain_ok = false
        flags << { severity: "high", code: "broken_hash_chain", message: "Chain discontinuity at #{w.window_start.iso8601}" }
        break
      end
      prev_hash = w.chain_hash
    end

    # Layer 2: Cross-verify surviving telemetry SHAs against Hackatime's persisted GitHub commits table
    recorded_shas = windows.filter_map(&:git_head_sha).uniq
    verified_commit_count = if recorded_shas.any?
      Commit.where(user_id: submission.user_id, sha: recorded_shas).count
    else
      0
    end
    git_ok = recorded_shas.any? && verified_commit_count > 0

    if submission.submitted_hours.to_f >= 2.0 && recorded_shas.empty?
      flags << {
        severity: "high",
        code: "missing_git_commit_corroboration",
        message: "Claimed #{submission.submitted_hours}h with zero recorded Git commit SHAs"
      }
    elsif submission.submitted_hours.to_f >= 2.0 && verified_commit_count == 0
      flags << {
        severity: "medium",
        code: "unverified_remote_commits",
        message: "No local Git SHAs matched synced surviving remote commits yet"
      }
    end

    # Surviving diff-persistence corroboration
    total_persisted_diff_lines = windows.sum(&:persisted_diff_lines)
    if submission.submitted_hours.to_f >= 1.0 && total_persisted_diff_lines == 0
      flags << {
        severity: "high",
        code: "zero_persisted_diff_lines",
        message: "Claimed #{submission.submitted_hours}h with 0 persisted diff lines across #{windows.size} windows"
      }
    end

    # Layer 3: Fraud Squad Pattern Analysis (SP Ledger gated ratio, Tier-C share, repetitive signatures)
    tier_c_count = windows.count { |w| (w.provenance_mask & 4) != 0 }
    plugin_share = windows.any? ? ((tier_c_count.to_f / windows.size) * 100.0).round(2) : 0.0

    if plugin_share > 30.0
      flags << {
        severity: "high",
        code: "excessive_tier_c_plugin_share",
        message: "Tier C Plugin SDK present in #{plugin_share}% of windows (>30% threshold)"
      }
    end

    # Skilled-builder fairness: only flag flat 6h 1.00x streaks when AI-heavy AND lacking persisted diff/commit evidence.
    # Skilled manual builders writing clean code & passing tests without compiler errors are NOT flagged.
    ai_flat_streak = 0
    max_ai_flat_streak = 0
    windows.each do |w|
      errors = w.signal_counts.is_a?(Hash) ? w.signal_counts["SIG_ERROR_LOOP"].to_i : 0
      is_ai_session = w.ai_harness.present? && w.ai_harness != "none"
      if is_ai_session && w.effective_multiplier.to_f >= 0.999 && errors == 0 && w.persisted_diff_lines == 0
        ai_flat_streak += 1
        max_ai_flat_streak = [ max_ai_flat_streak, ai_flat_streak ].max
      else
        ai_flat_streak = 0
      end
    end
    if max_ai_flat_streak >= 72
      flags << {
        severity: "high",
        code: "impossible_flat_ai_multiplier",
        message: "#{max_ai_flat_streak} consecutive AI 1.00x windows (~#{(max_ai_flat_streak / 12.0).round(1)}h) with zero errors and zero persisted diffs"
      }
    end

    # Fraud Squad pattern check: repeated identical per-window signal fingerprints (e.g. scripted loops)
    same_sig_streak = 0
    max_same_sig_streak = 0
    prev_sig = nil
    windows.each do |w|
      sig = [ (w.signal_counts || {}).sort.to_a, w.effective_multiplier_milli, w.persisted_diff_lines ]
      if sig == prev_sig && sig.first.any?
        same_sig_streak += 1
        max_same_sig_streak = [ max_same_sig_streak, same_sig_streak ].max
      else
        same_sig_streak = 1
        prev_sig = sig
      end
    end
    if max_same_sig_streak >= 12
      flags << {
        severity: "medium",
        code: "repeated_identical_window_pattern",
        message: "#{max_same_sig_streak} consecutive windows had identical signal counts & multiplier fingerprints (review pattern)"
      }
    end

    # Summarize gated/suppressed SP attempts from the PostgreSQL SP Ledger
    total_events = events.count
    gated_events = events.gated.count
    if total_events >= 10 && (gated_events.to_f / total_events) > 0.35
      pct = ((gated_events.to_f / total_events) * 100.0).round(1)
      flags << {
        severity: "medium",
        code: "high_gated_sp_ratio",
        message: "#{gated_events}/#{total_events} (#{pct}%) SP ledger entries were suppressed by persistence/dedup/oscillation gates"
      }
    end

    # Surface oscillation / keyword-stuffing anomaly flags recorded on windows
    oscillation_windows = windows.count { |w| Array(w.anomaly_flags).include?("oscillating_error_loop") }
    if oscillation_windows >= 2
      flags << {
        severity: "high",
        code: "oscillating_reset_loop_pattern",
        message: "#{oscillation_windows} windows exhibited repeated error/reset oscillation without net repo progress"
      }
    end

    converted_hours = (windows.select(&:converted?).sum(&:credited_seconds) / 3600.0).round(2)
    if (submission.submitted_hours.to_f - converted_hours).abs > 0.25
      flags << {
        severity: "medium",
        code: "submitted_vs_converted_mismatch",
        message: "Submitted #{submission.submitted_hours}h vs #{converted_hours}h converted on /my/struggle"
      }
    end

    submission.update!(
      chain_verified: chain_ok,
      git_push_verified: git_ok,
      plugin_share_pct: plugin_share,
      anomaly_flags: flags
    )

    # Layer 4: Cryptographically unpredictable stratified audit sampling
    AuditSamplingService.apply!(submission)
  end
end
