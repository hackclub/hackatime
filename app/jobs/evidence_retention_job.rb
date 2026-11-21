# Crypto-shreds revealed evidence once a decision's appeal window has passed:
# frame ciphertext is purged and released segment keys are wiped. Draft
# ships nobody submitted are dropped after 30 days. A block's network
# metadata (IP address and TLS fingerprint) is cleared 30 days after it
# arrived, unless a reviewer is still looking at a ship covering it.
# Idempotent.
class EvidenceRetentionJob < ApplicationJob
  queue_as :literally_whenever

  NETWORK_METADATA_TTL = 30.days

  def perform
    under_review = EvidenceShip.where(status: %i[submitted needs_info appealed])
      .where("evidence_ships.desktop_device_id = evidence_blocks.desktop_device_id")
      .where("evidence_blocks.seq BETWEEN evidence_ships.from_seq AND evidence_ships.to_seq")
    EvidenceBlock.where(received_at: ...NETWORK_METADATA_TTL.ago).where("ip_address IS NOT NULL OR ja4_id IS NOT NULL")
      .where.not(under_review.arel.exists).in_batches(of: 5_000) { |batch| batch.update_all(ip_address: nil, ja4_id: nil) }

    EvidenceShip.decided.where(decided_at: ...EvidenceShip::APPEAL_WINDOW.ago).find_each do |ship|
      ship.evidence_frames.where.not(segment_key: nil).find_each(&:shred!)
    end
    EvidenceShip.draft.where(created_at: ...30.days.ago).find_each(&:destroy!)
  end
end
