# A user's claim that a range of their chain produced shipped work. Shipping
# reveals the device's beacon secrets for that range, which pick the required timelapse
# frames and code snapshots; the user uploads them and the server scores it.
# The range is contiguous, but the user may remove minutes inside it before
# shipping: `excluded_ranges` holds them as sorted, merged [from, to] seq
# pairs. A removed minute earns nothing, reveals nothing and is never checked.
class EvidenceShip < ApplicationRecord
  REQUIRED_FRAME_RATIO = 0.028 # about five of the 180 timelapse frames an hour
  SPOT_CHECK_RATIO = 0.08 # about one of the twelve snapshots an hour, beyond the first and last
  APPEAL_WINDOW = 90.days
  MAX_EXCLUDED_RANGES = 200

  belongs_to :user
  belongs_to :desktop_device
  belongs_to :reviewer, class_name: "User", optional: true
  has_many :evidence_frames, dependent: :destroy
  has_many :evidence_views, dependent: :delete_all

  enum :status, { draft: 0, submitted: 1, needs_info: 2, approved: 3, deflated: 4, rejected: 5, appealed: 6 }

  validates :project, presence: true, length: { maximum: 200 }
  validates :from_seq, :to_seq, numericality: { only_integer: true, greater_than: 0 }
  validate :range_is_ordered_and_closed, on: :create
  validate :range_does_not_overlap
  validate :excluded_ranges_fit_the_range

  scope :review_queue, -> { where(status: %i[submitted appealed]).order(Arel.sql("jsonb_array_length(flags) DESC"), :submitted_at) }
  scope :decided, -> { where(status: %i[approved deflated rejected]) }

  def blocks = desktop_device.evidence_blocks.in_range(from_seq, to_seq)
  def decided? = approved? || deflated? || rejected?

  # Sorts the ranges and merges the ones that overlap or touch. Anything that
  # is not a list of ordered integer pairs is kept as given, for the
  # validation to refuse.
  def excluded_ranges=(ranges)
    return super unless well_formed_ranges?(ranges)

    super(ranges.sort.each_with_object([]) do |(from, to), merged|
      if merged.any? && from <= merged.last[1] + 1
        merged.last[1] = [ merged.last[1], to ].max
      else
        merged << [ from, to ]
      end
    end)
  end

  def kept?(seq) = excluded_ranges.none? { |from, to| seq.between?(from, to) }
  def kept_blocks = excluded_ranges.reduce(blocks) { |scope, (from, to)| scope.where.not(seq: from..to) }
  def removed_minutes = excluded_ranges.sum { |from, to| to - from + 1 }

  # Reveals this device's secrets for the beacons of the kept minutes and
  # records which timelapse frames must be uploaded and which code snapshots
  # will be checked: the first and last, plus every one its own secret picks.
  # Every choice depends only on the block, never on the draft. The device
  # can no longer chain blocks under a revealed beacon, so it cannot use a
  # secret to pick what a later block reveals.
  #
  # Removed minutes are left out of all of it. A draft may be opened again
  # with other minutes removed, so this also counts the checks that removing
  # dodged (see below) and brings the uploaded frames in line.
  def reveal!
    uid = desktop_device.uid
    desktop_device.with_lock do
      loaded = blocks.includes(:evidence_beacon).to_a
      secrets = loaded.to_h { |block| [ block.seq, block.evidence_beacon.device_secret(uid) ] }
      required_in = lambda do |block|
        block.frames.map { |frame| frame["hash"] }.select { |hash| Evidence::Crypto.required_frame?(secrets[block.seq], hash, REQUIRED_FRAME_RATIO) }
      end
      kept, removed = loaded.partition { |block| kept?(block.seq) }
      required = kept.flat_map(&required_in).uniq
      picked = ->(block) { Evidence::Crypto.spot_check?(secrets[block.seq], block.tree_root, SPOT_CHECK_RATIO) }
      with_trees = kept.select(&:tree_root)
      spot_check_seqs = ([ with_trees.first, with_trees.last ].compact + with_trees.select(&picked)).map(&:seq).uniq.sort
      # A removed minute that an earlier draft kept has had its secret
      # revealed: the device knew what would be checked in it when the user
      # took it out. Each required frame no kept minute still owes is one
      # dodged check, and so is each snapshot that was going to be
      # spot-checked: one its secret picks, or one this draft listed as its
      # first or last. Which snapshots are first and last depends on what was
      # removed, so the draft remembers every seq it ever listed; the stored
      # spot_check_seqs alone would forget a dodged one at the next open.
      # Minutes removed before any reveal never count.
      known = removed.select(&:revealed_at)
      dodged_frames = known.flat_map(&required_in).uniq - required
      dodged_snapshots = known.select { |block| block.tree_root && (asked_spot_check_seqs.include?(block.seq) || picked.(block)) }
      revealed_through = [ desktop_device.revealed_through_minute, *kept.map { |block| block.evidence_beacon.minute } ].compact.max
      desktop_device.update!(revealed_through_minute: revealed_through)
      EvidenceBlock.where(id: kept.reject(&:revealed_at).map(&:id)).update_all(revealed_at: Time.current)
      update!(required_frames: required, spot_check_seqs:, asked_spot_check_seqs: (asked_spot_check_seqs | spot_check_seqs).sort,
        removed_checks: dodged_frames.length + dodged_snapshots.length)

      # Frames uploaded to an earlier version of this draft follow the kept
      # minutes: one that only removed minutes commit is deleted, and one a
      # kept minute also commits (an unchanged screen repeats its hash) moves there.
      committed_by = kept.reverse.flat_map { |block| block.frames.map { |frame| [ frame["hash"], block ] } }.to_h
      evidence_frames.find_each do |frame|
        block = committed_by[frame.frame_hash] or next frame.destroy!
        frame.update!(seq: block.seq, captured_at_ms: block.captured_at_ms, required: required.include?(frame.frame_hash))
      end
    end
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

    # Drafts may overlap each other; at most one ship may ever leave draft
    # for any minute, so the same work is never credited twice.
    overlap = desktop_device.evidence_ships.where.not(status: :draft).where.not(id:).where("from_seq <= ? AND to_seq >= ?", to_seq, from_seq)
    errors.add(:base, "This range overlaps a ship you already submitted") if overlap.exists?
  end

  def well_formed_ranges?(ranges)
    ranges.is_a?(Array) && ranges.all? { |range| range.is_a?(Array) && range.length == 2 && range.all?(Integer) && range[0] <= range[1] }
  end

  def excluded_ranges_fit_the_range
    return if excluded_ranges == [] || from_seq.blank? || to_seq.blank?
    return errors.add(:base, "Each excluded range needs an integer from_seq and to_seq, with from_seq not after to_seq") unless well_formed_ranges?(excluded_ranges)

    return errors.add(:base, "Excluded ranges must lie inside the ship's range") unless excluded_ranges.all? { |from, to| from >= from_seq && to <= to_seq }

    errors.add(:base, "A ship can have at most #{MAX_EXCLUDED_RANGES} excluded ranges") if excluded_ranges.length > MAX_EXCLUDED_RANGES
    errors.add(:base, "A ship must keep at least one minute") if removed_minutes > to_seq - from_seq
  end
end
