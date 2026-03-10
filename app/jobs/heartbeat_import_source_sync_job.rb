class HeartbeatImportSourceSyncJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  retry_on WakatimeCompatibleClient::TransientError,
    wait: ->(executions) { (executions**2).seconds + rand(1..4).seconds },
    attempts: 8

  good_job_control_concurrency_with(
    key: -> { "heartbeat_import_source_sync_job_#{arguments.first}" },
    total_limit: 1
  )

  def perform(source_id)
    return unless Flipper.enabled?(:wakatime_imports)

    source = HeartbeatImportSource.find_by(id: source_id)
    return unless source&.sync_enabled?
    return if source.paused?

    initialize_backfill_if_needed(source)

    if source.backfilling?
      schedule_next_backfill_day(source)
      return
    end

    source.update!(status: :syncing)
    enqueue_day_sync(source, Date.yesterday)
    enqueue_day_sync(source, Date.current)
  rescue WakatimeCompatibleClient::AuthenticationError => e
    source&.update!(
      sync_enabled: false,
      status: :paused,
      last_error_message: e.message.to_s.truncate(500),
      last_error_at: Time.current
    )
    HeartbeatImportSource.increment_counter(:consecutive_failures, source.id) if source
  rescue WakatimeCompatibleClient::TransientError => e
    source&.update!(
      status: source&.backfilling? ? :backfilling : :failed,
      last_error_message: e.message.to_s.truncate(500),
      last_error_at: Time.current
    )
    HeartbeatImportSource.increment_counter(:consecutive_failures, source.id) if source
    raise
  rescue WakatimeCompatibleClient::RequestError => e
    source&.update!(
      status: :failed,
      last_error_message: e.message.to_s.truncate(500),
      last_error_at: Time.current
    )
    HeartbeatImportSource.increment_counter(:consecutive_failures, source.id) if source
  end

  private

  def initialize_backfill_if_needed(source)
    should_initialize = source.idle? ||
      (source.failed? && source.backfill_cursor_date.blank? && source.last_synced_at.blank?)
    return unless should_initialize
    return unless source.backfill_cursor_date.blank?

    start_date = source.initial_backfill_start_date
    end_date = source.initial_backfill_end_date || Date.current

    if start_date.blank?
      start_date = source.client.fetch_all_time_since_today_start_date
    end

    if start_date > end_date
      source.update!(
        status: :syncing,
        backfill_cursor_date: nil,
        initial_backfill_start_date: start_date,
        initial_backfill_end_date: end_date
      )
      return
    end

    source.update!(
      status: :backfilling,
      initial_backfill_start_date: start_date,
      initial_backfill_end_date: end_date,
      backfill_cursor_date: start_date,
      last_error_message: nil,
      last_error_at: nil,
      consecutive_failures: 0
    )
  end

  BACKFILL_WINDOW_SIZE = 5

  def schedule_next_backfill_day(source)
    cursor = source.backfill_cursor_date
    end_date = source.initial_backfill_end_date || Date.current
    return if cursor.blank?

    if cursor > end_date
      source.update!(status: :syncing, backfill_cursor_date: nil)
      self.class.perform_later(source.id)
      return
    end

    days_scheduled = 0
    date = cursor
    while date <= end_date && days_scheduled < BACKFILL_WINDOW_SIZE
      enqueue_day_sync(source, date)
      days_scheduled += 1
      date += 1.day
    end

    source.update!(backfill_cursor_date: date)

    if date <= end_date
      self.class.perform_later(source.id)
    end
  end

  def enqueue_day_sync(source, date)
    HeartbeatImportSourceSyncDayJob.perform_later(source.id, date.iso8601)
  end
end
