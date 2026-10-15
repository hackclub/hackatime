class TrustLevelAuditLog < ApplicationRecord
  TRUST_LEVELS = { blue: "blue", red: "red", green: "green", yellow: "yellow" }.freeze
  EDIT_WINDOW = 7.days

  belongs_to :user
  belongs_to :changed_by, class_name: "User"
  belongs_to :edited_by, class_name: "User", optional: true

  has_paper_trail on: [ :update ], only: %i[reason notes]

  validates :previous_trust_level, :new_trust_level, :user_id, :changed_by_id, presence: true

  enum :previous_trust_level, TRUST_LEVELS, prefix: :previous
  enum :new_trust_level, TRUST_LEVELS, prefix: :new

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :by_admin, ->(admin) { where(changed_by: admin) }

  def trust_level_change_description = "#{previous_trust_level.capitalize} → #{new_trust_level.capitalize}"
  def admin_name = changed_by.display_name

  def edited? = edited_at.present?

  def editable_by?(editor)
    editor.is_a?(User) &&
      editor == changed_by &&
      editor.admin_level.in?(%w[admin superadmin ultraadmin]) &&
      created_at > EDIT_WINDOW.ago
  end

  def amend!(reason:, notes:, edited_by:)
    return true if reason == self.reason && notes == self.notes

    unless edited?
      self.original_reason = self.reason
      self.original_notes = self.notes
    end
    update!(reason: reason, notes: notes, edited_by: edited_by, edited_at: Time.current)
  end

  def edit_json
    {
      edited_at: edited_at,
      edited_by: edited_by && { id: edited_by.id, username: edited_by.username, display_name: edited_by.display_name },
      original_reason: original_reason,
      original_notes: original_notes
    }
  end
end
