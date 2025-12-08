class DeletionRequest < ApplicationRecord
  belongs_to :user
  belongs_to :admin_approved_by, class_name: "User", optional: true

  enum :status, {
    pending: 0,
    approved: 1,
    cancelled: 2,
    completed: 3
  }

  validates :requested_at, presence: true
  validate :user_not_banned_from_deletion, on: :create

  scope :active, -> { where(status: [ :pending, :approved ]) }
  scope :ready_for_deletion, -> { approved.where("scheduled_deletion_at <= ?", Time.current) }

  def self.create_for_user!(user)
    create!(
      user: user,
      requested_at: Time.current,
      status: :pending
    )
  end

  def approve!(admin)
    update!(
      status: :approved,
      admin_approved_by: admin,
      admin_approved_at: Time.current,
      scheduled_deletion_at: Time.current + 30.days # grace period, if shit changes, change this
    )
  end

  def cancel!
    update!(
      status: :cancelled,
      cancelled_at: Time.current
    )
  end

  def complete!
    update!(
      status: :completed,
      completed_at: Time.current
    )
  end

  def days_until_deletion
    return nil unless scheduled_deletion_at.present?
    [ (scheduled_deletion_at.to_date - Date.current).to_i, 0 ].max
  end

  def can_be_cancelled?
    pending? || approved?
  end

  private

  def user_not_banned_from_deletion
    return unless user.present?

    if user.red?
      last_audit = user.trust_level_audit_logs.order(created_at: :desc).first
      if last_audit && last_audit.created_at > 365.days.ago
        errors.add(:base, "You can not request data deletion due to a recent ban")
      end
    end
  end
end
