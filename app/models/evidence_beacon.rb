# The server's public randomness for one minute. `value` is published at once
# and mixed into every block of that minute, proving the block was not made
# earlier. `secret` stays private until a ship reveals it; only its
# commitment is public, so required timelapse frames cannot be predicted.
class EvidenceBeacon < ApplicationRecord
  encrypts :secret

  has_many :evidence_blocks, dependent: :restrict_with_exception

  def self.current_minute = Time.current.to_i / 60

  def self.for_minute!(minute)
    find_by(minute:) || begin
      secret = SecureRandom.hex(32)
      create_or_find_by!(minute:) do |beacon|
        beacon.value = SecureRandom.hex(32)
        beacon.secret = secret
        beacon.commitment = Evidence::Crypto.beacon_commitment(secret)
      end
    end
  end

  def self.current! = for_minute!(current_minute)

  def as_public_json
    { minute:, value:, commitment:, starts_at: Time.at(minute * 60).utc.iso8601, server_time_ms: (Time.current.to_f * 1000).to_i }
  end
end
