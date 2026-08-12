class DashboardRollupRefreshJob < ApplicationJob
  queue_as :default

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1, key: -> { "dashboard_rollup_refresh_job_#{arguments.first}" }
  )

  DEFAULT_WAIT = 2.minutes
  ENQUEUE_CACHE_KEY_PREFIX = "dashboard_rollup_refresh_enqueued".freeze

  def self.schedule_for(user_id, wait: DEFAULT_WAIT)
    return if HeartbeatRepository.clickhouse?
    return unless DashboardRollup.mark_dirty(user_id)

    enqueue_dirty(user_id, wait:)
  end

  def self.enqueue_dirty(user_id, wait: DEFAULT_WAIT)
    return unless Rails.cache.write(enqueue_cache_key(user_id), true, expires_in: wait + 1.minute, unless_exist: true)
    set(wait: wait).perform_later(user_id)
  end

  def self.enqueue_cache_key(user_id) = "#{ENQUEUE_CACHE_KEY_PREFIX}_#{user_id}"

  def perform(user_id = nil)
    return if HeartbeatRepository.clickhouse?

    unless user_id
      User.where("dashboard_rollup_generation > dashboard_rollup_refreshed_generation")
        .limit(1_000).pluck(:id).each { |id| self.class.enqueue_dirty(id, wait: 0.seconds) }
      return
    end

    user = User.find_by(id: user_id)
    return unless user

    generation = DashboardRollup.generation(user_id)
    DashboardRollupRefreshService.new(user:).call
    DashboardRollup.mark_refreshed(user_id, generation)
  ensure
    if user_id && !HeartbeatRepository.clickhouse?
      Rails.cache.delete(self.class.enqueue_cache_key(user_id))
      self.class.enqueue_dirty(user_id, wait: 0.seconds) if DashboardRollup.dirty?(user_id)
    end
  end
end
