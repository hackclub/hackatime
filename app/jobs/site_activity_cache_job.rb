# Recomputes the site-wide activity caches every minute (cron), so requests read
# them instead of scanning every user's recent heartbeats.
class SiteActivityCacheJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(total_limit: 1, key: -> { "site_activity_cache" })

  def perform
    Heartbeat.recent_counts(force: true)
    Heartbeat.active_users_by_hour(force: true)
    Heartbeat.minutes_logged_last_hour(force: true)
    CurrentlyHacking.count(force: true)
    CurrentlyHacking.data(force: true)
    ProjectRepoMapping.currently_active_by_user(force: true)
    HeartbeatRollup.site_totals(force: true)
  end
end
