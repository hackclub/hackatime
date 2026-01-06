class AdminApiKey < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: { scope: :user_id }

  before_validation :generate_token!, on: :create

  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(
      revoked_at: Time.current,
      name: "#{name}_revoked_#{SecureRandom.hex(8)}"
    )
  end

  private

  def generate_token!
    # should be jazzy enough
    self.token ||= "hka_#{SecureRandom.hex(32)}"
  end
end
