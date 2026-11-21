# Reviewer summary of a ship, built from structured metadata only.
module Evidence
  module Summary
    module_function

    # Counts describe the minutes the ship keeps; the ones the user removed
    # before shipping are only counted, in removed_minutes.
    def facts(ship)
      blocks = ship.kept_blocks.to_a
      {
        project: ship.project,
        minutes: blocks.length,
        removed_minutes: ship.removed_minutes, removed_checks: ship.removed_checks,
        claimed: ship.claimed_seconds, scored: ship.scored_seconds, ceiling: ship.ceiling_seconds, credited: ship.credited_seconds,
        confidence: ship.confidence, scorer: ship.scorer,
        prompts: EvidenceBlock.ai_total(blocks, "prompts"),
        ai_lines: EvidenceBlock.ai_total(blocks, "ai_lines"),
        human_lines: EvidenceBlock.ai_total(blocks, "human_lines"),
        commits: blocks.sum { |block| block.payload["commits"].to_i },
        builds: blocks.sum { |block| block.payload["builds"].to_i },
        research_minutes: blocks.count { |block| block.focus == "research" },
        unrelated_minutes: blocks.count { |block| block.focus == "unrelated" },
        frames: ship.evidence_frames.count, redacted_frames: ship.evidence_frames.where(redacted: true).count,
        flags: ship.flags,
        spot_checks: ship.spot_checks.map { |check| check.slice("seq", "root_ok", "plausible", "overlap", "shared_files", "compared") },
        stretches: ship.stretches.map { |stretch| stretch.slice("from_seq", "to_seq", "counted_seconds", "confidence", "reasons") }
      }
    end

    def plain(facts)
      hours = ->(seconds) { seconds ? format("%dh %02dm", seconds / 3600, seconds % 3600 / 60) : "n/a" }
      lines = []
      lines << "#{facts[:minutes]} chained minutes on #{facts[:project]}: #{facts[:prompts]} AI prompts, " \
               "#{facts[:commits]} commits, #{facts[:builds]} builds, #{facts[:human_lines]} human and #{facts[:ai_lines]} AI lines."
      lines << "Claimed #{hours.(facts[:claimed])}, scored #{hours.(facts[:scored])} at #{(facts[:confidence].to_f * 100).round}% " \
               "confidence (#{facts[:scorer]}), output ceiling #{hours.(facts[:ceiling])}, suggested credit #{hours.(facts[:credited])}."
      lines << "#{facts[:research_minutes]} research and #{facts[:unrelated_minutes]} unrelated minutes; " \
               "#{facts[:frames]} frames revealed, #{facts[:redacted_frames]} redacted."
      if facts[:removed_minutes].positive?
        checks = facts[:removed_checks]
        line = "The user removed #{facts[:removed_minutes]} #{"minute".pluralize(facts[:removed_minutes])} of the range before shipping; " \
               "they earn nothing and are not counted above."
        # Minutes taken out after a draft had told the device what it would check in them.
        line += " That took out #{checks} #{"check".pluralize(checks)} the server had already asked for (required frames or code snapshots)." if checks.positive?
        lines << line
      end
      checks = facts[:spot_checks]
      rooted = checks.select { |check| check["root_ok"] }
      led = rooted.count { |check| check["plausible"] && check["compared"] }
      blind = rooted.count { |check| check["shared_files"].to_i.zero? }
      line = "Code spot-checks: #{rooted.length} of #{checks.length} matched their committed roots; #{led} disclosed shipped code that leads to the shipped repo."
      line += " #{blind} disclosed no shipped file, so they prove nothing about the shipped repo and the output ceiling may be too high." if blind.positive?
      lines << line
      lines << (facts[:flags].any? ? "Flags: #{facts[:flags].join(", ")}." : "No flags.")
      lines.join("\n")
    end

    # What the student sees: their own week in plain words. Never flags,
    # confidence, scorer internals or how the evidence is checked. Minutes
    # they removed before shipping are not part of it.
    def reflection(ship)
      blocks = ship.kept_blocks.to_a
      minutes = blocks.count { |block| %w[project research].include?(block.focus) && block.payload["active_s"].to_i.positive? }
      prompts = EvidenceBlock.ai_total(blocks, "prompts")
      commits = blocks.sum { |block| block.payload["commits"].to_i }
      human = EvidenceBlock.ai_total(blocks, "human_lines")
      ai = EvidenceBlock.ai_total(blocks, "ai_lines")
      research = blocks.count { |block| block.focus == "research" }
      parts = [ "You spent #{minutes} focused minutes on #{ship.project}" ]
      parts << "made #{commits} #{"commit".pluralize(commits)}" if commits.positive?
      parts << "sent #{prompts} AI #{"prompt".pluralize(prompts)}" if prompts.positive?
      lines = [ parts.to_sentence + "." ]
      lines << "You wrote about #{human} lines yourself and accepted about #{ai} from AI." if human + ai > 0
      lines << "#{research} of those minutes went on reading docs and researching." if research.positive?
      lines.join(" ")
    end

    def llm(facts)
      url = ENV["EVIDENCE_LLM_URL"].presence or return
      uri = URI(url)
      body = {
        model: ENV.fetch("EVIDENCE_LLM_MODEL", "gpt-4o-mini"),
        messages: [
          { role: "system", content: "You summarise a student's coding session for a reviewer and for the student. " \
            "Use only the JSON facts and call the project \"the project\". Five short sentences, British English, no em dashes. " \
            "Name anything a reviewer should check first." },
          # The project name is the only free text the client chose; it stays
          # out so it cannot steer the summary a reviewer reads.
          { role: "user", content: facts.except(:project).to_json }
        ]
      }
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 30) do |http|
        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "Authorization" => "Bearer #{ENV["EVIDENCE_LLM_KEY"]}")
        request.body = body.to_json
        http.request(request)
      end
      return unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig("choices", 0, "message", "content").presence
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, JSON::ParserError => e
      Rails.logger.warn("Evidence summary LLM unavailable: #{e.class}")
      nil
    end
  end
end
