class EmailVerificationRequest < ApplicationRecord
  RESEND_COOLDOWN = 10.minutes

  belongs_to :user

  validates :email, presence: true,
                   uniqueness: { conditions: -> { where(deleted_at: nil) } },
                   format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: { conditions: -> { where(deleted_at: nil) } }
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create
  before_validation :downcase_email

  scope :valid, -> { where("expires_at > ? AND deleted_at IS NULL", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def resend_available_at
    ([ created_at, updated_at ].compact.max || Time.current) + RESEND_COOLDOWN
  end

  def resend_available?
    resend_available_at <= Time.current
  end

  def resend_cooldown_seconds
    seconds = (resend_available_at - Time.current).ceil
    [ seconds, 0 ].max
  end

  def refresh_for_resend!
    update!(
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 30.minutes.from_now
    )
  end

  def verify!
    email_address = user.email_addresses.create!(
      email: email,
      source: :signing_in
    )

    soft_delete!

    email_address
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= 30.minutes.from_now
  end

  def downcase_email
    self.email = email.downcase if email.present?
  end
end
