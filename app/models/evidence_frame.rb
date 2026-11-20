# A screenshot frame the user chose to reveal at ship. The ciphertext is
# stored as-is; its released segment key is encrypted at rest and both are
# destroyed after the decision plus the appeal window.
class EvidenceFrame < ApplicationRecord
  belongs_to :evidence_ship
  has_one_attached :ciphertext

  encrypts :segment_key

  validates :frame_hash, format: { with: Evidence::Crypto::HEX64 }
  validates :kind, inclusion: { in: %w[timelapse] }

  def plaintext
    Evidence::Crypto.aead_open(Base64.strict_decode64(segment_key), ciphertext.download)
  end

  def shred!
    ciphertext.purge if ciphertext.attached?
    update!(segment_key: nil)
  end
end
