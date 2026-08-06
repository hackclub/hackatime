class HCAIdentityConflict < ApplicationRecord
  belongs_to :email_user, class_name: "User", optional: true
  belongs_to :slack_user, class_name: "User", optional: true

  validates :hca_id, :reason, :last_seen_at, presence: true

  def self.record!(error)
    conflict = where(hca_id: error.hca_id, resolved_at: nil).first_or_initialize
    conflict.assign_attributes(
      reason: error.reason,
      email_user_id: error.email_user_id,
      slack_user_id: error.slack_user_id,
      last_seen_at: Time.current,
      occurrences: conflict.persisted? ? conflict.occurrences + 1 : 1
    )
    conflict.save!
    conflict
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
