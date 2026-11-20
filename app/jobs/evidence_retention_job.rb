# Crypto-shreds revealed evidence once a decision's appeal window has passed:
# frame ciphertext is purged and released segment keys are wiped. Draft
# ships nobody submitted are dropped after 30 days. Idempotent.
class EvidenceRetentionJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    EvidenceShip.decided.where(decided_at: ...EvidenceShip::APPEAL_WINDOW.ago).find_each do |ship|
      ship.evidence_frames.where.not(segment_key: nil).find_each(&:shred!)
    end
    EvidenceShip.draft.where(created_at: ...30.days.ago).find_each(&:destroy!)
  end
end
