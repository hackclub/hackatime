# Submits a ship: checks required frames are present, verifies the server's
# spot-checked snapshots against their committed roots, sets the output
# ceiling from the final repo, scores the range and writes the reviewer
# summary. Nothing is credited until a reviewer decides.
module Evidence
  class ShipSubmission
    class Invalid < StandardError; end

    def self.call(...) = new(...).call

    # final_files: [{ path, content }] tracked shipped files only.
    # snapshots: [{ seq, salt, entries }] for every ship.spot_check_seqs.
    def initialize(ship:, final_files:, snapshots:)
      @ship = ship
      @final_files = SnapshotCheck.decode_files(final_files)
      @snapshots = Array(snapshots).index_by { |snapshot| snapshot["seq"].to_i }
    end

    def call
      raise Invalid, "Only drafts can be submitted" unless @ship.draft?

      missing = @ship.missing_required_frames
      raise Invalid, "#{missing.length} required frame(s) are missing" if missing.any?

      blocks = @ship.blocks.includes(:evidence_beacon).to_a
      by_seq = blocks.index_by(&:seq)
      first_files = nil
      checks = @ship.spot_check_seqs.map do |seq|
        snapshot = @snapshots[seq]
        next { "seq" => seq, "root_ok" => false, "plausible" => false, "missing" => true } unless snapshot

        leaves, files = SnapshotCheck.decode_snapshot(snapshot["salt"].to_s, snapshot["entries"])
        first_files ||= files
        SnapshotCheck.check(block: by_seq.fetch(seq), salt_hex: snapshot["salt"], leaves:, files:, final_files: @final_files)
      end

      research_ratio = blocks.empty? ? 0 : blocks.count { |block| block.focus == "research" }.fdiv(blocks.length)
      ai_lines = EvidenceBlock.ai_total(blocks, "ai_lines")
      ceiling = SnapshotCheck.ceiling_seconds(first_files: first_files || {}, final_files: @final_files, ai_lines:, research_ratio:)
      result = Scorer.call(ship: @ship, blocks:, ceiling_seconds: ceiling)

      flags = result.flags.dup
      flags << "snapshot_mismatch" if checks.any? { |check| !check["root_ok"] }
      flags << "implausible_history" if checks.any? { |check| check["root_ok"] && !check["plausible"] }
      # A snapshot sent as leaf hashes only proves its root and nothing about
      # the shipped repo; without a disclosed first snapshot the output
      # ceiling counts every shipped line as written in this range.
      flags << "undisclosed_snapshot" if checks.any? { |check| check["root_ok"] && check["shared_files"].zero? }
      flags << "redacted_frames" if @ship.evidence_frames.where(redacted: true).exists?
      flags << "unshipped_gaps" if blocks.each_cons(2).any? { |a, b| b.minute - a.minute > 30 }
      flags << "offline_blocks" if blocks.any?(&:offline)
      # A snapshot that does not match its root is a broken claim: no credit.
      credited = flags.include?("snapshot_mismatch") ? 0 : result.credited_seconds

      # Serialises submissions of one device so two overlapping drafts
      # cannot both pass the overlap check in EvidenceShip.
      @ship.desktop_device.with_lock do
        raise Invalid, "Only drafts can be submitted" unless @ship.reload.draft?

        @ship.update!(
          status: :submitted, submitted_at: Time.current, spot_checks: checks, flags: flags.uniq,
          stretches: result.stretches.map { |stretch| serialize(stretch) },
          claimed_seconds: result.claimed_seconds, scored_seconds: result.scored_seconds,
          ceiling_seconds: ceiling, credited_seconds: credited, confidence: result.confidence, scorer: result.scorer
        )
      end
      EvidenceSummaryJob.perform_later(@ship.id)
      @ship
    rescue ArgumentError, KeyError => e
      raise Invalid, e.message
    rescue ActiveRecord::RecordInvalid => e
      raise Invalid, e.record.errors.full_messages.to_sentence
    end

    private

    def serialize(stretch)
      { "from_seq" => stretch.from_seq, "to_seq" => stretch.to_seq, "seconds" => stretch.seconds,
        "counted_seconds" => stretch.counted_seconds, "confidence" => stretch.confidence,
        "reasons" => stretch.reasons, "flags" => stretch.flags,
        "features" => stretch.features.transform_values { |value| value.is_a?(Float) ? value.round(3) : value } }
    end
  end
end
