class MirrorFanoutEnqueueJob < ApplicationJob
  queue_as :latency_10s

  DEBOUNCE_TTL = 10.seconds

  def perform(user_id)
    return if debounced?(user_id)

    User.find_by(id: user_id)&.wakatime_mirrors&.active&.pluck(:id)&.each do |mirror_id|
      WakatimeMirrorSyncJob.perform_later(mirror_id)
    end
  end

  private

  def debounced?(user_id)
    key = "mirror_fanout_enqueue_job:user:#{user_id}"
    return true if Rails.cache.read(key)

    Rails.cache.write(key, true, expires_in: DEBOUNCE_TTL)
    false
  end
end
