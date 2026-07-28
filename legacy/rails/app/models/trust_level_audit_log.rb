class TrustLevelAuditLog < ApplicationRecord
  TRUST_LEVELS = { blue: "blue", red: "red", green: "green", yellow: "yellow" }.freeze

  belongs_to :user
  belongs_to :changed_by, class_name: "User"

  validates :previous_trust_level, :new_trust_level, :user_id, :changed_by_id, presence: true

  enum :previous_trust_level, TRUST_LEVELS, prefix: :previous
  enum :new_trust_level, TRUST_LEVELS, prefix: :new

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_admin, ->(admin) { where(changed_by: admin) }

  def trust_level_change_description = "#{previous_trust_level.capitalize} → #{new_trust_level.capitalize}"
  def admin_name = changed_by.display_name
end
