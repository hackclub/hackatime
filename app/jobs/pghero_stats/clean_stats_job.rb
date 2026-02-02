class PgheroStats::CleanStatsJob < ApplicationJob
  queue_as :literally_whenever

  KEEP_DAYS = 30

  def perform
    PgHero.clean_query_stats(before: KEEP_DAYS.days.ago)
    PgHero.clean_space_stats(before: KEEP_DAYS.days.ago)
  end
end
