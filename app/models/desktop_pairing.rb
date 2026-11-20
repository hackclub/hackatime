# Short-lived PKCE pairing grant. The desktop app sends a code challenge to
# the browser, the signed-in user approves it, and only the app holding the
# matching verifier can exchange the code for a device token.
class DesktopPairing < ApplicationRecord
  TTL = 10.minutes

  belongs_to :user

  validates :code_challenge, format: { with: /\A[A-Za-z0-9_-]{43}\z/ }

  # Hackatime Desktop always records a timelapse, so a pairing only exists
  # once the user has consented to it.
  def self.issue!(user:, code_challenge:, consented:)
    raise ArgumentError, "Consent to timelapse capture is required" unless consented

    code = SecureRandom.alphanumeric(10).upcase
    pairing = create!(user:, code_challenge:, code_digest: DesktopDevice.digest(code), expires_at: TTL.from_now,
      capture_consented_at: Time.current)
    [ pairing, code ]
  end

  # Consumes the pairing at most once, even under concurrent exchanges.
  def self.consume!(code:, code_verifier:)
    pairing = find_by(code_digest: DesktopDevice.digest(code.to_s.strip.upcase))
    return if pairing.nil? || code_verifier.blank?

    challenge = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(code_verifier), padding: false)
    return unless ActiveSupport::SecurityUtils.secure_compare(challenge, pairing.code_challenge)

    claimed = where(id: pairing.id, consumed_at: nil).where("expires_at > ?", Time.current).update_all(consumed_at: Time.current)
    pairing if claimed == 1
  end
end
