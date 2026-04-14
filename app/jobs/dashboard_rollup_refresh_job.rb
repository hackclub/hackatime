class DashboardRollupRefreshJob < ApplicationJob
  queue_as :default

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "dashboard_rollup_refresh_job_#{arguments.first}" },
    drop: true
  )

  DEFAULT_WAIT = 2.minutes
  ENQUEUE_CACHE_KEY_PREFIX = "dashboard_rollup_refresh_enqueued".freeze

  def self.schedule_for(user_id, wait: DEFAULT_WAIT)
    DashboardRollup.mark_dirty(user_id)

    return if Rails.cache.exist?(enqueue_cache_key(user_id))

    Rails.cache.write(enqueue_cache_key(user_id), true, expires_in: wait + 1.minute)
    set(wait: wait).perform_later(user_id)
  end

  def self.enqueue_cache_key(user_id)
    "#{ENQUEUE_CACHE_KEY_PREFIX}_#{user_id}"
  end

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    DashboardRollupRefreshService.new(user: user).call
  ensure
    Rails.cache.delete(self.class.enqueue_cache_key(user_id))
  end
end
