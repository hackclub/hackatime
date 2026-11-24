# Normalized PostgreSQL ledger recording exactly HOW every user earned (or had gated)
# each Struggle Point signal inside every 5-minute Struggle Window.
# Strictly aggregate & privacy-safe (zero raw prompts, code, or keystroke logs).
class StrugglePointEvent < ApplicationRecord
  SIGNAL_LABELS = {
    "SIG_ARCH_STEER"       => "Architectural Steering",
    "SIG_VISUAL_GUIDE"     => "Visual / Diagram Guidance",
    "SIG_FAULT_LOCALIZE"   => "Fault Localization",
    "SIG_DIFF_SURGERY"     => "Post-AI Diff Surgery",
    "SIG_ERROR_LOOP"       => "Error-to-Fix Debugging",
    "SIG_VERIFY_EXEC"      => "Build / Test Verification",
    "SIG_CODE_EXPLORE"     => "Codebase Exploration",
    "SIG_TECH_RESEARCH"    => "Technical Docs Research",
    "SIG_COURSE_CORRECT"   => "Prompt Course-Correction",
    "SIG_MANUAL_CODE"      => "Persisted Manual Coding",
    "SIG_GIT_HYGIENE"      => "Logical Git Commit Hygiene",
    "SIG_ROLLBACK_RECOVER" => "Rollback & Recovery"
  }.freeze

  GATE_STATUS_LABELS = {
    "awarded"                     => "Awarded",
    "capped"                      => "Awarded (Signal Cap)",
    "read_only_grace_cap"         => "Grace Cap (Read-Only Window)",
    "penalized_unverified_ai"     => "Halved (Unverified AI Burst)",
    "gated_no_diff"               => "Gated (0 Persisted Diff Lines)",
    "gated_read_only"             => "Gated (Consecutive Read-Only)",
    "gated_oscillation"           => "Gated (Reset / Error Loop Oscillation)",
    "gated_visual_dedup"          => "Gated (Near-Duplicate Visual dHash)",
    "gated_keyword_stuffing"      => "Gated (Prompt Keyword Stuffing)",
    "gated_uncorroborated_plugin" => "Gated (Uncorroborated Tier-C Plugin)",
    "gated_autonomous_ai"         => "Gated (Autonomous AI Self-Trigger)"
  }.freeze

  belongs_to :struggle_window
  belongs_to :user

  validates :project_hash, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :window_start, presence: true
  validates :signal_code, presence: true, inclusion: { in: SIGNAL_LABELS.keys }
  validates :trigger_count, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :provenance_tier, inclusion: { in: %w[tier_a tier_b tier_c] }

  scope :awarded, -> { where("awarded_points > 0") }
  scope :gated, -> { where(awarded_points: 0) }
  scope :for_project, ->(project_hash) { where(project_hash: project_hash) }

  def signal_label = SIGNAL_LABELS.fetch(signal_code, signal_code)
  def gate_label = GATE_STATUS_LABELS.fetch(gate_status, gate_status.humanize)

  def self.tier_from_mask(mask)
    m = mask.to_i
    return "tier_a" if (m & 1) != 0
    return "tier_b" if (m & 2) != 0

    "tier_c"
  end

  def self.signal_breakdown_summary(scope)
    rows = scope
      .group(:signal_code)
      .pluck(
        :signal_code,
        Arel.sql("SUM(trigger_count)"),
        Arel.sql("SUM(raw_points)"),
        Arel.sql("SUM(awarded_points)"),
        Arel.sql("SUM(CASE WHEN awarded_points = 0 THEN 1 ELSE 0 END)"),
        Arel.sql("COUNT(*)")
      )

    rows.map do |code, triggers, raw_pts, awarded_pts, gated_windows, total_windows|
      {
        signal_code: code,
        label: SIGNAL_LABELS.fetch(code, code),
        trigger_count: triggers.to_i,
        raw_points: raw_pts.to_f.round(2),
        awarded_points: awarded_pts.to_f.round(2),
        gated_windows: gated_windows.to_i,
        total_windows: total_windows.to_i
      }
    end.sort_by { |r| -r[:awarded_points] }
  end
end
