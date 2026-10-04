class Ja4 < ApplicationRecord
  # Heartbeats are in ClickHouse, so nullifying their ja4_id on destroy would be
  # a table-wide mutation there. JA4 rows are reference data and are never
  # deleted in normal operation; refuse rather than leave dangling ids silently.
  has_many :heartbeats, dependent: :restrict_with_exception

  validates :fingerprint, presence: true

  def self.resolve(fingerprint)
    normalized_fingerprint = fingerprint.to_s.strip.presence
    return if normalized_fingerprint.nil?

    find_by(fingerprint: normalized_fingerprint) ||
      create_or_find_by!(fingerprint: normalized_fingerprint)
  end
end
