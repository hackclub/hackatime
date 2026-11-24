class StruggleWindow < ApplicationRecord
  GENESIS_CHAIN_HASH = ("0" * 64).freeze

  belongs_to :user
  belongs_to :struggle_conversion, optional: true
  has_many :struggle_point_events, dependent: :destroy

  scope :unconverted, -> { where(converted_at: nil) }
  scope :converted, -> { where.not(converted_at: nil) }

  validates :project_hash, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :window_start, presence: true
  validates :raw_seconds, numericality: { only_integer: true, in: 0..300 }
  validates :convertible_seconds, numericality: { only_integer: true, in: 0..300 }
  validates :credited_seconds, numericality: { only_integer: true, in: 0..300 }
  validates :effective_multiplier, numericality: { in: 0.0..1.0 }
  validates :effective_multiplier_milli, numericality: { only_integer: true, in: 0..1000 }
  validates :provenance_mask, numericality: { only_integer: true, in: 0..7 }
  validates :prev_chain_hash, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :server_nonce, presence: true, format: { with: /\A[0-9a-f]{32}\z/ }
  validates :chain_hash, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :signature, presence: true, length: { is: 64 }

  def converted? = converted_at.present?

  def self.last_chain_hash_for(user_id:, project_hash:)
    where(user_id: user_id, project_hash: project_hash)
      .order(window_start: :desc)
      .limit(1)
      .pick(:chain_hash) || GENESIS_CHAIN_HASH
  end
end
