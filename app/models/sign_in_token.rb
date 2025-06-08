class SignInToken < ApplicationRecord
  belongs_to :user

  enum :auth_type, {
    email: 0,
    slack: 1,
    program_magic_link: 2
  }

  validates :token, presence: true, uniqueness: true
  validates :auth_type, presence: true
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :valid, -> { where("expires_at > ? AND used_at IS NULL", Time.current) }

  def mark_used!
    update!(used_at: Time.current)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= 30.minutes.from_now
  end
end
