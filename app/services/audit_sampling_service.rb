require "securerandom"

# Cryptographically unpredictable stratified audit sampler for Hack Club Fraud Squad.
# Ensures no submitter can predict whether a submission will be manually audited:
#   - High-risk / high-hour (>=20h, broken chain, >30% Tier C, or high-severity flags) -> 100%
#   - Medium-risk (>=5h or any medium anomaly flag) -> 40% random draw
#   - Baseline floor (all remaining clean submissions) -> 12% unpredictable random draw
class AuditSamplingService
  HIGH_HOURS_THRESHOLD = 20.0
  MEDIUM_HOURS_THRESHOLD = 5.0
  MEDIUM_SAMPLE_RATE = 0.40
  BASELINE_SAMPLE_RATE = 0.12

  Result = Data.define(:selected, :sampled_randomly, :reason)

  def self.evaluate(submission:, rng: nil)
    flags = Array(submission.anomaly_flags)
    has_high_flag = flags.any? { |f| f["severity"] == "high" || f[:severity] == "high" }
    has_medium_flag = flags.any? { |f| f["severity"] == "medium" || f[:severity] == "medium" }
    hours = submission.submitted_hours.to_f

    if !submission.chain_verified || has_high_flag || submission.plugin_share_pct.to_f > 30.0 || hours >= HIGH_HOURS_THRESHOLD
      return Result.new(selected: true, sampled_randomly: false, reason: "mandatory_high_risk")
    end

    roll = rng ? rng.call : SecureRandom.random_number

    if has_medium_flag || hours >= MEDIUM_HOURS_THRESHOLD
      if roll < MEDIUM_SAMPLE_RATE
        return Result.new(selected: true, sampled_randomly: true, reason: "stratified_medium_sample")
      end
      return Result.new(selected: false, sampled_randomly: false, reason: "not_sampled_medium")
    end

    if roll < BASELINE_SAMPLE_RATE
      Result.new(selected: true, sampled_randomly: true, reason: "unpredictable_baseline_sample")
    else
      Result.new(selected: false, sampled_randomly: false, reason: "not_sampled_baseline")
    end
  end

  def self.apply!(submission, rng: nil)
    res = evaluate(submission: submission, rng: rng)
    submission.update!(
      sampled_randomly: res.sampled_randomly,
      sampling_reason: res.reason
    )
    res
  end
end
