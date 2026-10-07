class DashboardRollupRefreshJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  # One rebuild runs at a time per user, and one more may wait behind it so
  # heartbeats that arrive during a rebuild are picked up by the next one.
  good_job_control_concurrency_with(
    enqueue_limit: 1, perform_limit: 1, key: -> { "dashboard_rollup_refresh_job_#{arguments.first}" }
  )

  DEFAULT_WAIT = 2.minutes
  ENQUEUE_CACHE_KEY_PREFIX = "dashboard_rollup_refresh_enqueued".freeze

  def self.schedule_for(user_id, wait: DEFAULT_WAIT)
    return unless Rails.cache.write(enqueue_cache_key(user_id), true, expires_in: wait + 1.minute, unless_exist: true)
    set(wait: wait).perform_later(user_id)
  end

  def self.enqueue_cache_key(user_id) = "#{ENQUEUE_CACHE_KEY_PREFIX}_#{user_id}"

  def perform(user_id)
    # Cleared before reading heartbeats, so anything written from here on
    # schedules another rebuild.
    Rails.cache.delete(self.class.enqueue_cache_key(user_id))
    user = User.find_by(id: user_id)
    HeartbeatRollup.rebuild!(user) if user
  end
end
