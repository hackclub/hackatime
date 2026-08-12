class Ja4 < ApplicationRecord
  has_many :heartbeats

  before_destroy :prepare_heartbeat_nullification

  validates :fingerprint, presence: true

  def self.resolve(fingerprint)
    normalized_fingerprint = fingerprint.to_s.strip.presence
    return if normalized_fingerprint.nil?

    find_by(fingerprint: normalized_fingerprint) ||
      create_or_find_by!(fingerprint: normalized_fingerprint)
  end

  def heartbeats
    return super unless HeartbeatRepository.clickhouse?

    HeartbeatRepository.current.all.where(ja4_id: id)
  end

  private

  def prepare_heartbeat_nullification
    if HeartbeatRepository.clickhouse?
      HeartbeatRepository.current.prepare_ja4_nullification(id)
    else
      HeartbeatRepository.ensure_writes_enabled!
      HeartbeatRepository.ensure_mutations_enabled!
    end
  end
end
