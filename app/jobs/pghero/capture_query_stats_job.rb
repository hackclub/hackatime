class Pghero::CaptureQueryStatsJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    PgHero.capture_query_stats
  end
end
