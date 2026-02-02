class PgheroStats::CaptureSpaceStatsJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    PgHero.capture_space_stats
  end
end
