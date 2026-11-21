# A paired Hackatime Desktop install. It authenticates with its own bearer
# token, owns one append-only hash chain of minute blocks and optionally a
# hardware key that signs every block. Hardware is a small confidence bonus,
# never a requirement. Capture is always timelapse; pairing requires consent.
class DesktopDevice < ApplicationRecord
  PLATFORMS = %w[macos windows linux].freeze
  MAX_NEW_DEVICES_PER_MONTH = 3

  belongs_to :user
  has_many :evidence_blocks, dependent: :delete_all
  has_many :evidence_ships, dependent: :destroy

  enum :key_tier, { software: 0, secure_enclave: 1, tpm: 2, app_attest: 3 }, prefix: :key

  validates :uid, :name, :token_digest, :capture_consented_at, presence: true
  validates :platform, inclusion: { in: PLATFORMS }
  validates :name, length: { maximum: 100 }
  validate :enrolment_rate_limit, on: :create

  scope :active, -> { where(revoked_at: nil) }

  def self.digest(value) = OpenSSL::Digest::SHA256.hexdigest(value.to_s)

  def self.authenticate(token)
    return if token.blank?

    active.includes(:user).find_by(token_digest: digest(token))
  end

  # One account per physical machine. The raw identifier never reaches the
  # database; a keyed hash still lets us refuse a second account.
  def self.hardware_digest(hardware_id)
    return if hardware_id.blank?

    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "desktop-hardware:#{hardware_id}")
  end

  def self.build_with_token(**attributes)
    token = SecureRandom.base58(40)
    device = new(uid: SecureRandom.uuid, token_digest: digest(token), **attributes)
    [ device, token ]
  end

  def public_key_object
    @public_key_object ||= OpenSSL::PKey.read(Base64.strict_decode64(public_key)) if public_key.present?
  end

  # ECDSA P-256 over the 32 raw bytes of a block hash (Secure Enclave and TPM
  # both produce X9.62 DER signatures of SHA-256(message)).
  def valid_signature?(block_hash_hex, signature_b64)
    return false if public_key_object.nil? || signature_b64.blank?

    public_key_object.verify("SHA256", Base64.strict_decode64(signature_b64), [ block_hash_hex ].pack("H*"))
  rescue ArgumentError, OpenSSL::PKey::PKeyError
    false
  end

  # Only an Apple-attested key is verified; secure_enclave and tpm are what
  # the client said, so they are recorded but earn nothing.
  def confidence_bonus = key_app_attest? ? Evidence::Config.current.dig(:weights, :attested) : 0.0

  def revoke! = update!(revoked_at: Time.current)
  def revoked? = revoked_at.present?

  private

  # Counts machines, not pairings: unpairing and pairing the same Mac again
  # must not use up the allowance. A revoked pairing counts only when it had
  # enrolled a machine that is not paired now.
  def enrolment_rate_limit
    return unless user

    recent = user.desktop_devices.where(created_at: 30.days.ago..)
    active = recent.active
    machines = active.count + recent.where.not(revoked_at: nil).where.not(hardware_id_digest: nil)
      .where.not(hardware_id_digest: active.where.not(hardware_id_digest: nil).select(:hardware_id_digest)).distinct.count(:hardware_id_digest)
    errors.add(:base, "Too many new devices this month") if machines >= MAX_NEW_DEVICES_PER_MONTH
  end
end
