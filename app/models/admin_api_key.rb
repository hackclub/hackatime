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

  def record_usage
    used_at = Time.current
    cutoff = used_at - 1.minute
    return if usage_tracking_enqueued_at && usage_tracking_enqueued_at > cutoff

    # Claim the sampling window atomically, even when requests authenticate concurrently.
    # The timestamp already loaded during authentication keeps hot keys read-only.
    self.class.transaction do
      claimed = self.class.where(id: id)
        .where("usage_tracking_enqueued_at IS NULL OR usage_tracking_enqueued_at <= ?", cutoff)
        .update_all(usage_tracking_enqueued_at: used_at)
      RecordAdminApiKeyUsageJob.perform_later(id, used_at) if claimed.positive?
    end
  end

  private

  def generate_token!
    self.token ||= "hka_#{SecureRandom.hex(32)}"
    self.token_preview = token.first(TOKEN_PREVIEW_LENGTH)
  end
end
