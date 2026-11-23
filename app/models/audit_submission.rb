class AuditSubmission < ApplicationRecord
  REVIEW_STATUSES = %w[pending approved deflated rejected].freeze

  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_one_attached :bundle_file

  validates :project_hash, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :program_slug, presence: true, length: { maximum: 64 }
  validates :bundle_sha256, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :submitted_hours, numericality: { greater_than_or_equal_to: 0 }
  validates :review_status, inclusion: { in: REVIEW_STATUSES }

  def project_windows
    user.struggle_windows.where(project_hash: project_hash).order(:window_start)
  end
end
