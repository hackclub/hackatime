class Ja4 < ApplicationRecord
  has_many :heartbeats, dependent: :nullify

  validates :fingerprint, presence: true

  def self.resolve(fingerprint)
    normalized_fingerprint = fingerprint.to_s.strip.presence
    return if normalized_fingerprint.nil?

    create_or_find_by!(fingerprint: normalized_fingerprint)
  end
end
