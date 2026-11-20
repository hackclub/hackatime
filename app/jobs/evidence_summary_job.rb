# Writes the reviewer summary for a submitted ship. The same text doubles as
# the user's weekly reflection. When EVIDENCE_LLM_URL (an OpenAI-compatible
# chat completions endpoint) is set, an LLM writes it from the ship's
# structured metadata only (never frames or source); otherwise a
# deterministic summary is used. Safe to retry: it overwrites one field.
class EvidenceSummaryJob < ApplicationJob
  queue_as :literally_whenever

  def perform(ship_id)
    ship = EvidenceShip.find_by(id: ship_id)
    return unless ship&.submitted? || ship&.appealed?

    facts = Evidence::Summary.facts(ship)
    ship.update!(summary: Evidence::Summary.llm(facts) || Evidence::Summary.plain(facts))
  end
end
