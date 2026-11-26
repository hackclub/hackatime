class StruggleWindow < ApplicationRecord
  GENESIS_CHAIN_HASH = ("0" * 64).freeze
  MAX_WINDOW_SECONDS = 300
  MIN_STRUGGLE_POINTS = 2.0.to_d
  CALIBRATION_TARGET_SP = 10.0.to_d

  belongs_to :user
  belongs_to :struggle_conversion, optional: true
  has_many :struggle_point_events, dependent: :destroy

  scope :unconverted, -> { where(converted_at: nil) }
  scope :converted, -> { where.not(converted_at: nil) }

  validates :project_hash, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :window_start, presence: true
  validates :raw_seconds, numericality: { only_integer: true, in: 0..MAX_WINDOW_SECONDS }
  validates :convertible_seconds, numericality: { only_integer: true, in: 0..MAX_WINDOW_SECONDS }
  validates :credited_seconds, numericality: { only_integer: true, in: 0..MAX_WINDOW_SECONDS }
  validates :struggle_points, numericality: { greater_than_or_equal_to: 0 }
  validates :diversity_multiplier, numericality: { in: 0.0..2.0 }
  validates :verify_multiplier, numericality: { in: 0.0..1.0 }
  validates :effective_multiplier, numericality: { in: 0.0..1.0 }
  validates :effective_multiplier_milli, numericality: { only_integer: true, in: 0..1000 }
  validates :provenance_mask, numericality: { only_integer: true, in: 0..7 }
  validates :prev_chain_hash, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :server_nonce, presence: true, format: { with: /\A[0-9a-f]{32}\z/ }
  validates :chain_hash, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :signature, presence: true, length: { is: 64 }

  validate :credit_bounds_match_struggle_points

  def converted? = converted_at.present?

  def self.last_chain_hash_for(user_id:, project_hash:)
    where(user_id: user_id, project_hash: project_hash)
      .order(window_start: :desc)
      .limit(1)
      .pick(:chain_hash) || GENESIS_CHAIN_HASH
  end

  private

  def credit_bounds_match_struggle_points
    return if raw_seconds.nil? || convertible_seconds.nil? || credited_seconds.nil? ||
              struggle_points.nil? || effective_multiplier.nil? || effective_multiplier_milli.nil?

    if convertible_seconds > raw_seconds
      errors.add(:convertible_seconds, "must be less than or equal to raw_seconds")
    end

    if credited_seconds > convertible_seconds
      errors.add(:credited_seconds, "must be less than or equal to convertible_seconds")
    end

    if struggle_points.to_d < MIN_STRUGGLE_POINTS
      if convertible_seconds.positive?
        errors.add(:convertible_seconds, "must be 0 when struggle_points is below #{MIN_STRUGGLE_POINTS.to_f}")
      end
      if effective_multiplier.to_d.positive? || effective_multiplier_milli.positive?
        errors.add(:effective_multiplier, "must be 0 when struggle_points is below #{MIN_STRUGGLE_POINTS.to_f}")
      end
      return
    end

    sp_cap_multiplier = [ struggle_points.to_d / CALIBRATION_TARGET_SP, 1.to_d ].min
    max_multiplier = [ sp_cap_multiplier + 0.001.to_d, 1.to_d ].min
    if effective_multiplier.to_d > max_multiplier
      errors.add(:effective_multiplier, "exceeds the maximum multiplier allowed for struggle_points")
    end

    max_milli = [ (sp_cap_multiplier * 1000).ceil, 1000 ].min
    if effective_multiplier_milli > max_milli
      errors.add(:effective_multiplier_milli, "exceeds the maximum multiplier allowed for struggle_points")
    end

    if (effective_multiplier.to_d * 1000 - effective_multiplier_milli).abs > 1
      errors.add(:effective_multiplier_milli, "must match effective_multiplier")
    end

    max_by_sp = [ raw_seconds, (raw_seconds * sp_cap_multiplier).ceil ].min
    if convertible_seconds > max_by_sp
      errors.add(:convertible_seconds, "exceeds the per-window cap allowed for struggle_points")
    end

    max_by_multiplier = [ raw_seconds, (raw_seconds * effective_multiplier.to_d).ceil ].min
    if convertible_seconds > max_by_multiplier
      errors.add(:convertible_seconds, "exceeds raw_seconds scaled by effective_multiplier")
    end
  end
end
