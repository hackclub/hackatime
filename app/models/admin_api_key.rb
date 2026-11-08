class AdminApiKey < ApplicationRecord
  TOKEN_PREVIEW_LENGTH = 13

  # Each admin API endpoint requires exactly one of these. The user's admin
  # level still applies on top, so a scope never grants more than its owner has.
  SCOPES = {
    "users:read" => "Look up users and read their profiles, stats, projects and trust history",
    "users:write" => "Convict users and amend trust level audit logs",
    "heartbeats:read" => "Read heartbeats, IP addresses, machines, alts and the timeline",
    "bans:read" => "View heartbeat bans",
    "bans:write" => "Ban and unban heartbeats",
    "leaderboard_shadowbans:read" => "View leaderboard shadowbans",
    "leaderboard_shadowbans:write" => "Shadowban and unshadowban users from leaderboards",
    "deletion_requests:read" => "View account deletion requests",
    "deletion_requests:write" => "Approve and reject account deletion requests",
    "permissions:read" => "View admin levels",
    "permissions:write" => "Change admin levels",
    "admin_api_keys:read" => "View admin API keys",
    "admin_api_keys:write" => "Create and revoke admin API keys"
  }.freeze

  belongs_to :user

  attribute :token, :string
  # Never write the plaintext token or its digest to versions; usage timestamps are noise.
  has_paper_trail skip: %i[token token_bidx], ignore: %i[last_used_at usage_tracking_enqueued_at expiry_notice_sent_at]
  blind_index :token, algorithm: :pbkdf2_sha256, cost: { iterations: 1 }

  normalizes :scopes, with: ->(scopes) { scopes.compact_blank.map(&:to_s).uniq }

  validates :token_bidx, presence: true, uniqueness: true
  validates :token_preview, presence: true
  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :scopes, presence: true
  validate :scopes_must_exist

  before_validation :generate_token!, on: :create

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where(revoked_at: nil, expires_at: ..Time.current) }

  def active? = revoked_at.nil? && (expires_at.nil? || expires_at.future?)

  def scope?(scope) = scopes.include?(scope)

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

  def scopes_must_exist
    unknown = scopes - SCOPES.keys
    errors.add(:scopes, "include unknown scopes: #{unknown.join(", ")}") if unknown.any?
  end

  def generate_token!
    self.token ||= "hka_#{SecureRandom.hex(32)}"
    self.token_preview = token.first(TOKEN_PREVIEW_LENGTH)
  end
end
