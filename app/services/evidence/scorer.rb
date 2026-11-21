# Scores a ship. Rules run first and decide what is countable at all; the
# optional calibrated model (or the rules-only weights) then gives each
# stretch a confidence, and the output ceiling caps the total.
#
# Rules, in order:
# * mouse movement alone never counts, and a jiggler score above the
#   threshold or a high share of injected input zeroes the minute;
# * a run of identical frames zeroes the minutes it covers;
# * minutes claimed for another project count nothing, not even as a short
#   switch away, so two ships can never credit the same minute;
# * switches away of `grace_seconds` or less still count;
# * AI wait, research and testing count only when an edit, prompt or commit
#   follows within `follow_up_seconds`; otherwise the stretch is capped.
module Evidence
  class Scorer
    Stretch = Data.define(:from_seq, :to_seq, :seconds, :counted_seconds, :confidence, :features, :reasons, :flags)
    Result = Data.define(:stretches, :claimed_seconds, :scored_seconds, :ceiling_seconds, :credited_seconds, :confidence, :flags, :scorer)

    WORK_FOCUS = %w[project research].freeze
    FRAME_REPORT_MS = 120_000

    def self.call(...) = new(...).call

    def initialize(ship:, blocks: ship.blocks.includes(:evidence_beacon).to_a, ceiling_seconds: nil)
      @ship = ship
      @blocks = blocks
      @ceiling_seconds = ceiling_seconds
      @config = Config.current
      @model = Model.load
    end

    def call
      minutes = @blocks.map { |block| classify(block) }
      flag_duplicate_frames!(minutes)
      stretches = group(minutes).map { |group| score(group) }
      claimed = minutes.sum { |minute| minute[:active] }
      scored = stretches.sum { |stretch| (stretch.counted_seconds * stretch.confidence).round }
      credited = @ceiling_seconds ? [ scored, @ceiling_seconds ].min : scored
      flags = stretches.flat_map(&:flags).uniq
      flags << "output_ceiling" if @ceiling_seconds && scored > @ceiling_seconds
      weighted = stretches.sum(&:counted_seconds).positive? ? stretches.sum { |s| s.counted_seconds * s.confidence } / stretches.sum(&:counted_seconds) : 0.0
      Result.new(stretches:, claimed_seconds: claimed, scored_seconds: scored, ceiling_seconds: @ceiling_seconds,
        credited_seconds: credited, confidence: weighted.round(3), flags:, scorer: @model ? @model.name : "rules")
    end

    private

    def classify(block)
      payload = block.payload
      active = payload["active_s"].to_i.clamp(0, 60)
      keys, clicks, moves = payload["keys"].to_i, payload["clicks"].to_i, payload["moves"].to_i
      injected = payload["injected"].to_i
      ai = block.ai
      engaged = keys + clicks + payload["edits"].to_i + ai["prompts"].to_i + payload["commits"].to_i
      reasons = []
      if engaged.zero? && !ai["waiting"]
        reasons << (moves.positive? ? "mouse_only" : "idle")
        active = 0
      end
      other_project = block.project.present? && !same_project?(block.project)
      if other_project
        reasons << "other_project"
        active = 0
      end
      if payload["jiggler"].to_f >= @config[:jiggler_threshold]
        reasons << "jiggler"
        active = 0
      end
      total_input = keys + clicks + moves
      if total_input.positive? && injected.to_f / total_input >= @config[:injected_ratio_threshold]
        reasons << "injected_input"
        active = 0
      end
      { block:, seq: block.seq, minute: block.minute, focus: payload["focus"], active:, keys:, clicks:, moves:, injected:,
        rhythm: payload["rhythm"], jiggler: payload["jiggler"].to_f, ai:, edits: payload["edits"].to_i,
        commits: payload["commits"].to_i, builds: payload["builds"].to_i, category: payload["category"],
        frames: block.frames, tree: block.tree_root, signed: block.signed, offline: block.offline, reasons:, other_project: }
    end

    def same_project?(name) = name.to_s.strip.casecmp?(@ship.project.to_s.strip)

    # The same frame hash (or perceptual hash) several minutes running means
    # a frozen or replayed screen, not work.
    def flag_duplicate_frames!(minutes)
      run = []
      last = nil
      flush = lambda do
        if run.length >= @config[:duplicate_frame_run]
          run.each { |minute| minute[:active] = 0; minute[:reasons] << "duplicate_frames" }
        end
        run = []
      end
      minutes.each do |minute|
        fingerprint = minute[:frames].map { |frame| frame["phash"] || frame["hash"] }.compact.last
        if fingerprint.nil?
          next
        elsif fingerprint == last
          run << minute
        else
          flush.call
          run = [ minute ]
        end
        last = fingerprint
      end
      flush.call
    end

    # Work minutes joined across short switches away (the grace period).
    def group(minutes)
      grace_minutes = (@config[:grace_seconds] / 60.0).floor
      groups = []
      current = []
      gap = []
      minutes.each do |minute|
        if (WORK_FOCUS.include?(minute[:focus]) && !minute[:other_project]) || minute[:reasons].include?("duplicate_frames")
          if current.any? && gap.any? && (gap.length > grace_minutes || minute[:minute] - current.last[:minute] - 1 > grace_minutes)
            groups << current
            current = []
          elsif current.any?
            gap.each { |away| away[:grace] = true unless away[:other_project] }
            current.concat(gap)
          end
          gap = []
          current << minute
        elsif current.any?
          gap << minute
        end
      end
      groups << current if current.any?
      groups
    end

    def score(group)
      seconds = group.sum { |minute| minute[:grace] ? 60 : minute[:active] }
      reasons = group.flat_map { |minute| minute[:reasons] }.tally
      flags = []
      flags << "injected_input" if reasons["injected_input"]
      flags << "jiggler" if reasons["jiggler"]
      flags << "duplicate_frames" if reasons["duplicate_frames"]

      follow_up = follow_up_present?(group)
      counted = group.sum { |minute| countable_seconds(minute, group) }
      counted = [ counted, @config[:no_follow_up_cap_seconds] ].min unless follow_up

      features = features_for(group, follow_up:)
      confidence = if counted.zero?
        0.0
      elsif @model
        @model.predict(features)
      else
        rules_confidence(features)
      end
      Stretch.new(from_seq: group.first[:seq], to_seq: group.last[:seq], seconds:, counted_seconds: counted,
        confidence: confidence.round(3), features:, reasons:, flags:)
    end

    # Research, testing and AI waiting minutes count only if a real edit,
    # prompt or commit follows within the follow-up window.
    def countable_seconds(minute, group)
      return 60 if minute[:grace]
      return 0 if minute[:other_project] || (minute[:active].zero? && !minute[:ai]["waiting"])

      conditional = minute[:focus] == "research" || minute[:ai]["waiting"] || %w[manual\ testing running\ tests].include?(minute[:category])
      return minute[:active] unless conditional

      window = @config[:follow_up_seconds] / 60
      later = group.select { |other| other[:minute] > minute[:minute] && other[:minute] <= minute[:minute] + window }
      used = later.any? { |other| other[:edits].positive? || other[:ai]["prompts"].to_i.positive? || other[:commits].positive? || other[:ai]["accepted"].to_i.positive? }
      return 0 unless used

      minute[:ai]["waiting"] && minute[:active].zero? ? 60 : minute[:active]
    end

    def follow_up_present?(group)
      group.any? { |minute| minute[:edits].positive? || minute[:commits].positive? || minute[:ai]["prompts"].to_i.positive? }
    end

    def features_for(group, follow_up:)
      count = group.length.to_f
      sum = ->(key) { group.sum { |minute| minute[key].to_i } }
      inputs = sum.(:keys) + sum.(:clicks) + sum.(:moves)
      rhythms = group.filter_map { |minute| minute[:rhythm] }
      frames_due = group.count { |minute| WORK_FOCUS.include?(minute[:focus]) && !minute[:other_project] }
      frames_on_time = group.count { |minute| on_time?(minute) }
      trees = group.filter_map { |minute| minute[:tree] }
      {
        "minutes" => count,
        "active_ratio" => group.sum { |minute| minute[:active] } / (count * 60),
        "keys_per_min" => sum.(:keys) / count,
        "clicks_per_min" => sum.(:clicks) / count,
        "moves_per_min" => sum.(:moves) / count,
        "injected_ratio" => inputs.zero? ? 0.0 : sum.(:injected).to_f / inputs,
        "rhythm" => rhythms.empty? ? 0.5 : rhythms.sum / rhythms.length,
        "jiggler" => group.map { |minute| minute[:jiggler] }.max || 0.0,
        "ai_prompts" => group.sum { |minute| minute[:ai]["prompts"].to_i },
        "ai_waiting_ratio" => group.count { |minute| minute[:ai]["waiting"] } / count,
        "edits" => sum.(:edits),
        "commits" => sum.(:commits),
        "builds" => sum.(:builds),
        "tree_changes" => trees.each_cons(2).count { |a, b| a != b },
        "frames" => group.sum { |minute| minute[:frames].length },
        "frames_due" => frames_due,
        "frames_on_time" => frames_on_time,
        "research_ratio" => group.count { |minute| minute[:focus] == "research" } / count,
        "unrelated_ratio" => group.count { |minute| minute[:grace] } / count,
        "follow_up" => follow_up ? 1.0 : 0.0,
        "offline_ratio" => group.count { |minute| minute[:offline] } / count,
        "signed_ratio" => group.count { |minute| minute[:signed] } / count,
        "duplicate_frames" => group.count { |minute| minute[:reasons].include?("duplicate_frames") },
        "hardware_tier" => @ship.desktop_device.key_app_attest? ? DesktopDevice.key_tiers.fetch("app_attest") : 0
      }
    end

    # Rules-only fallback: the published design's weights, overridable from
    # private config. Hardware only ever adds.
    def rules_confidence(features)
      weights = @config[:weights]
      score = 0.0
      score += weights[:streams_agree] if features["edits"].positive? || features["ai_prompts"].positive? || features["builds"].positive?
      score += weights[:follow_up] if features["follow_up"].positive?
      score += weights[:build_changed] if features["tree_changes"].positive? || features["commits"].positive?
      score += weights[:human_input] if features["rhythm"] >= @config[:human_rhythm_floor] && features["injected_ratio"] < 0.05
      score += weights[:frames_present] * frame_coverage(features)
      score += @ship.desktop_device.confidence_bonus * features["signed_ratio"]
      score *= 1 - (1 - @config[:offline_penalty]) * features["offline_ratio"]
      score.clamp(0.0, 1.0)
    end

    # The timelapse is server-paced: each work minute expects a frame near the
    # second its beacon chose, and missing or late frames cost credit.
    def frame_coverage(features)
      return features["frames"].positive? ? 1.0 : 0.0 if features["frames_due"].zero?

      [ features["frames_on_time"].to_f / features["frames_due"], 1.0 ].min
    end

    # A block reports the frames taken since the previous one, so each frame
    # is judged against the beacon of the minute it claims it was taken in.
    # at_ms is the client's word; it only counts when the server can bound
    # it: the block reached the server on time and the frame is no later
    # than the block and at most two minutes older.
    def on_time?(minute)
      return false if minute[:offline]

      window_ms = @config[:timelapse_window_seconds] * 1000
      captured_ms = minute[:block].captured_at_ms
      minute[:frames].any? do |frame|
        at_ms = frame["at_ms"]
        next false unless at_ms.is_a?(Integer) && at_ms <= captured_ms && captured_ms - at_ms <= FRAME_REPORT_MS

        taken = at_ms / 60_000
        value = beacon_values[taken] or next false
        (at_ms - (taken * 60 + Crypto.timelapse_second(value, @ship.desktop_device.uid)) * 1000).abs <= window_ms
      end
    end

    def beacon_values
      @beacon_values ||= begin
        first, last = @ship.blocks.minimum(:minute), @ship.blocks.maximum(:minute)
        first ? EvidenceBeacon.where(minute: (first - 2)..last).pluck(:minute, :value).to_h : {}
      end
    end
  end
end
