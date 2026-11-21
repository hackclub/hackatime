# One minute of a device's hash chain. The payload holds only summary claims
# (focus label, counts, scores, Merkle roots and encrypted frame hashes),
# never titles, URLs, keystrokes or source.
class EvidenceBlock < ApplicationRecord
  belongs_to :desktop_device
  belongs_to :user
  belongs_to :evidence_beacon
  belongs_to :ja4, optional: true

  FOCUS_LABELS = %w[project research unrelated unknown].freeze

  scope :in_range, ->(from_seq, to_seq) { where(seq: from_seq..to_seq).order(:seq) }

  def focus = payload["focus"]
  def project = payload["project"]
  def frames = Array(payload["frames"])
  def tree_root = payload.dig("tree", "root")

  # The AI claims of this minute (prompts, tokens, AI and human lines,
  # waiting, accepted); empty when the block made none.
  def ai = payload["ai"].is_a?(Hash) ? payload["ai"] : {}

  def self.ai_total(blocks, key) = blocks.sum { |block| block.ai[key].to_i }
end
