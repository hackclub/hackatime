# A user's claim that a range of their chain produced shipped work. Shipping
# reveals the beacon secrets for that range, which pick the required timelapse
# frames and code snapshots; the user uploads them and the server scores it.
class EvidenceShip < ApplicationRecord
  REQUIRED_FRAME_RATIO = 0.08 # about five of the sixty timelapse frames an hour
  SPOT_CHECK_SNAPSHOTS = 3
  APPEAL_WINDOW = 90.days

  belongs_to :user
  belongs_to :desktop_device
  belongs_to :reviewer, class_name: "User", optional: true
  has_many :evidence_frames, dependent: :destroy
  has_many :evidence_views, dependent: :delete_all

  enum :status, { draft: 0, submitted: 1, needs_info: 2, approved: 3, deflated: 4, rejected: 5, appealed: 6 }

  validates :project, presence: true, length: { maximum: 200 }
  validates :from_seq, :to_seq, numericality: { only_integer: true, greater_than: 0 }
  validate :range_is_ordered_and_closed, on: :create
  validate :range_does_not_overlap, on: :create

  scope :review_queue, -> { where(status: %i[submitted appealed]).order(Arel.sql("jsonb_array_length(flags) DESC"), :submitted_at) }
  scope :decided, -> { where(status: %i[approved deflated rejected]) }

  def blocks = desktop_device.evidence_blocks.in_range(from_seq, to_seq)
  def decided? = approved? || deflated? || rejected?

  # Reveals the committed beacon secrets of this range and records which
  # timelapse frames must be uploaded and which code snapshots will be checked.
  def reveal!
    loaded = blocks.includes(:evidence_beacon).to_a
    required = loaded.flat_map do |block|
      block.frames.select { |frame| Evidence::Crypto.required_frame?(block.evidence_beacon.secret, frame["hash"], REQUIRED_FRAME_RATIO) }
        .map { |frame| frame["hash"] }
    end
    with_trees = loaded.select(&:tree_root)
    spot_checks = [ with_trees.first, with_trees.last ]
    unless with_trees.empty?
      seed = Evidence::Crypto.sha256(loaded.last.evidence_beacon.secret + id.to_s)
      middle = with_trees[1...-1].sort_by { |block| Evidence::Crypto.sha256(seed + block.seq.to_s) }
      spot_checks += middle.first(SPOT_CHECK_SNAPSHOTS - 2)
    end
    update!(required_frames: required.uniq, spot_check_seqs: spot_checks.compact.map(&:seq).uniq.sort)
  end

  def missing_required_frames
    uploaded = evidence_frames.pluck(:frame_hash)
    required_frames - uploaded
  end

  def appealable? = (rejected? || deflated?) && decided_at && decided_at > APPEAL_WINDOW.ago && appeal.blank?

  def log_view!(viewer:, action:, frame: nil)
    evidence_views.create!(viewer:, action:, evidence_frame: frame)
  end

  private

  def range_is_ordered_and_closed
    return if from_seq.blank? || to_seq.blank? || desktop_device.nil?

    errors.add(:to_seq, "must not be before from_seq") if to_seq < from_seq
    errors.add(:to_seq, "is beyond the device's chain") if to_seq > desktop_device.last_seq
    errors.add(:base, "A ship can cover at most 24 hours") if to_seq - from_seq >= 24 * 60
  end

  def range_does_not_overlap
    return if from_seq.blank? || to_seq.blank? || desktop_device.nil?

    overlap = desktop_device.evidence_ships.where.not(status: :draft).where("from_seq <= ? AND to_seq >= ?", to_seq, from_seq)
    errors.add(:base, "This range overlaps a ship you already submitted") if overlap.exists?
  end
end
