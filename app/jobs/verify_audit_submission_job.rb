# Runs Layer 1 (chain linkage), Layer 2 (authoritative GitHub/GitLab commit DAG cross-check),
# and Layer 3 (statistical behavioral anomaly detection) asynchronously via GoodJob.
class VerifyAuditSubmissionJob < ApplicationJob
  queue_as :default

  def perform(audit_submission_id)
    submission = AuditSubmission.find_by(id: audit_submission_id)
    return unless submission

    windows = submission.project_windows.to_a
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

    # Layer 2: Cross-verify telemetry SHAs against Hackatime's persisted GitHub commits table
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
        message: "No local Git SHAs matched synced remote commits yet"
      }
    end

    # Layer 3: Statistical behavioral anomaly detection & Tier-C Plugin SDK segregation
    tier_c_count = windows.count { |w| (w.provenance_mask & 4) != 0 }
    plugin_share = windows.any? ? ((tier_c_count.to_f / windows.size) * 100.0).round(2) : 0.0

    if plugin_share > 30.0
      flags << {
        severity: "high",
        code: "excessive_tier_c_plugin_share",
        message: "Tier C Plugin SDK present in #{plugin_share}% of windows (>30% threshold)"
      }
    end

    # Detect impossible 6+ consecutive hours of flat 1.00x with zero error loops
    flat_perfect_streak = 0
    max_flat_streak = 0
    windows.each do |w|
      errors = w.signal_counts.is_a?(Hash) ? w.signal_counts["SIG_ERROR_LOOP"].to_i : 0
      if w.effective_multiplier.to_f >= 0.999 && errors == 0
        flat_perfect_streak += 1
        max_flat_streak = [ max_flat_streak, flat_perfect_streak ].max
      else
        flat_perfect_streak = 0
      end
    end
    if max_flat_streak >= 72
      flags << {
        severity: "high",
        code: "impossible_flat_multiplier",
        message: "#{max_flat_streak} consecutive 1.00x windows (~#{(max_flat_streak / 12.0).round(1)}h) with zero compiler/test errors"
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
  end
end
