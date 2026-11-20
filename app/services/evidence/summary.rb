# Reviewer summary of a ship, built from structured metadata only.
module Evidence
  module Summary
    module_function

    def facts(ship)
      blocks = ship.blocks.to_a
      {
        project: ship.project,
        minutes: blocks.length,
        claimed: ship.claimed_seconds, scored: ship.scored_seconds, ceiling: ship.ceiling_seconds, credited: ship.credited_seconds,
        confidence: ship.confidence, scorer: ship.scorer,
        prompts: blocks.sum { |block| block.payload.dig("ai", "prompts").to_i },
        ai_lines: blocks.sum { |block| block.payload.dig("ai", "ai_lines").to_i },
        human_lines: blocks.sum { |block| block.payload.dig("ai", "human_lines").to_i },
        commits: blocks.sum { |block| block.payload["commits"].to_i },
        builds: blocks.sum { |block| block.payload["builds"].to_i },
        research_minutes: blocks.count { |block| block.focus == "research" },
        unrelated_minutes: blocks.count { |block| block.focus == "unrelated" },
        frames: ship.evidence_frames.count, redacted_frames: ship.evidence_frames.where(redacted: true).count,
        flags: ship.flags,
        spot_checks: ship.spot_checks.map { |check| check.slice("seq", "root_ok", "plausible", "overlap") },
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
      passed = facts[:spot_checks].count { |check| check["plausible"] }
      lines << "Code spot-checks: #{passed} of #{facts[:spot_checks].length} matched their committed roots and lead to the shipped repo."
      lines << (facts[:flags].any? ? "Flags: #{facts[:flags].join(", ")}." : "No flags.")
      lines.join("\n")
    end

    # What the student sees: their own week in plain words. Never flags,
    # confidence, scorer internals or how the evidence is checked.
    def reflection(ship)
      blocks = ship.blocks.to_a
      minutes = blocks.count { |block| %w[project research].include?(block.focus) && block.payload["active_s"].to_i.positive? }
      prompts = blocks.sum { |block| block.payload.dig("ai", "prompts").to_i }
      commits = blocks.sum { |block| block.payload["commits"].to_i }
      human = blocks.sum { |block| block.payload.dig("ai", "human_lines").to_i }
      ai = blocks.sum { |block| block.payload.dig("ai", "ai_lines").to_i }
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
            "Use only the JSON facts. Five short sentences, British English, no em dashes. Name anything a reviewer should check first." },
          { role: "user", content: facts.to_json }
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
