class DocumentationFeedback < ApplicationRecord
  belongs_to :user, optional: true

  validates :helpful, inclusion: { in: [ true, false ] }
  validates :path, presence: true, length: { maximum: 255 }, format: { with: %r{\A/docs(?:/[^\r\n]*)?\z} }
  validates :title, presence: true, length: { maximum: 255 }
  validates :visitor_token,
    format: { with: %r{\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z}i },
    allow_nil: true
  validate :has_exactly_one_identity

  private

  def has_exactly_one_identity
    return if user_id.present? ^ visitor_token.present?

    errors.add(:base, "must belong to either a user or a visitor")
  end
end
