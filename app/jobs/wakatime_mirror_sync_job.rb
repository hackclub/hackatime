class WakatimeMirrorSyncJob < ApplicationJob
  queue_as :latency_10s

  include GoodJob::ActiveJobExtensions::Concurrency

  BATCH_SIZE = 25
  MAX_BATCHES_PER_RUN = 20

  class MirrorTransientError < StandardError; end

  retry_on MirrorTransientError,
    wait: ->(executions) { (executions**2).seconds + rand(1..4).seconds },
    attempts: 8

  retry_on HTTP::TimeoutError, HTTP::ConnectionError,
    wait: ->(executions) { (executions**2).seconds + rand(1..4).seconds },
    attempts: 8

  good_job_control_concurrency_with(
    key: -> { "wakatime_mirror_sync_job_#{arguments.first}" },
    total_limit: 1
  )

  def perform(mirror_id)
    mirror = WakatimeMirror.find_by(id: mirror_id)
    return unless mirror&.enabled?

    batches_processed = 0
    cursor = mirror.last_synced_heartbeat_id.to_i

    loop do
      batch = mirror.direct_heartbeats_after(cursor).limit(BATCH_SIZE).to_a
      break if batch.empty?

      response = mirror.post_heartbeats(batch.map { |heartbeat| mirror_payload(heartbeat) })
      status_code = response.status.to_i

      if response.status.success?
        cursor = batch.last.id
        mirror.update!(
          last_synced_heartbeat_id: cursor,
          last_synced_at: Time.current,
          consecutive_failures: 0,
          last_error_message: nil,
          last_error_at: nil
        )
      elsif [ 401, 403 ].include?(status_code)
        mirror.mark_auth_failed!("Authentication failed (#{status_code}). Check your API key.")
        return
      elsif transient_status?(status_code)
        mirror.record_transient_failure!("Mirror request failed with status #{status_code}.")
        raise MirrorTransientError, "Mirror request failed with status #{status_code}"
      else
        mirror.mark_failed!("Mirror request failed with status #{status_code}.")
        return
      end

      batches_processed += 1
      break if batches_processed >= MAX_BATCHES_PER_RUN
    end

    if batches_processed >= MAX_BATCHES_PER_RUN &&
      mirror.direct_heartbeats_after(cursor).exists?
      self.class.perform_later(mirror.id)
    end
  rescue HTTP::TimeoutError, HTTP::ConnectionError => e
    mirror&.record_transient_failure!("Mirror request failed: #{e.class.name}")
    raise
  end

  private

  def mirror_payload(heartbeat)
    heartbeat.attributes.slice(*payload_attributes)
  end

  def payload_attributes
    @payload_attributes ||= Heartbeat.indexed_attributes - [ "user_id" ]
  end

  def transient_status?(status_code)
    status_code == 408 || status_code == 429 || status_code >= 500
  end
end
