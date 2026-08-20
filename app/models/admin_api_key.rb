class AdminApiKey < ApplicationRecord
  TOKEN_PREVIEW_LENGTH = 13

  belongs_to :user

  attribute :token, :string
  blind_index :token, algorithm: :pbkdf2_sha256, cost: { iterations: 1 }

  validates :token_bidx, presence: true, uniqueness: true
  validates :token_preview, presence: true
  validates :name, presence: true, uniqueness: { scope: :user_id }

  before_validation :generate_token!, on: :create

  scope :active, -> { where(revoked_at: nil) }

  def active? = revoked_at.nil?

  def revoke!
    update!(revoked_at: Time.current, name: "#{name}_revoked_#{SecureRandom.hex(8)}")
  end

  private

  def generate_token!
    self.token ||= "hka_#{SecureRandom.hex(32)}"
    self.token_preview = token.first(TOKEN_PREVIEW_LENGTH)
  end
end
