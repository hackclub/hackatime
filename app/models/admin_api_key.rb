class AdminApiKey < ApplicationRecord
  belongs_to :user

  attr_reader :token

  validates :token_digest, presence: true, uniqueness: true
  validates :token_preview, presence: true
  validates :name, presence: true, uniqueness: { scope: :user_id }

  before_validation :generate_token!, on: :create

  scope :active, -> { where(revoked_at: nil) }

  def self.find_active_by_token(token)
    return if token.blank?

    active.find_by(token_digest: Digest::SHA256.hexdigest(token))
  end

  def active? = revoked_at.nil?

  def token=(token)
    @token = token
    self.token_digest = Digest::SHA256.hexdigest(token) if token.present?
    self.token_preview = token&.first(21)
  end

  def revoke!
    update!(revoked_at: Time.current, name: "#{name}_revoked_#{SecureRandom.hex(8)}")
  end

  private

  def generate_token! = self.token ||= "hka_#{SecureRandom.hex(32)}"
end
