# The server's public randomness for one minute. `value` is published at once
# and mixed into every block of that minute, proving the block was not made
# earlier. `secret` never leaves the server: each device gets a secret derived
# from it, whose commitment is public and which a ship reveals for that
# device only, so required frames and spot-checks cannot be predicted.
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

  def device_secret(device_uid) = Evidence::Crypto.device_secret(secret, device_uid)
  def device_commitment(device_uid) = Evidence::Crypto.beacon_commitment(device_secret(device_uid))

  def as_public_json(device_uid)
    { minute:, value:, commitment: device_commitment(device_uid), starts_at: Time.at(minute * 60).utc.iso8601, server_time_ms: (Time.current.to_f * 1000).to_i }
  end
end
