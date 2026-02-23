class HeartbeatImportSourceSyncJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  BACKFILL_WINDOW_DAYS = 5

  retry_on WakatimeCompatibleClient::TransientError,
    wait: ->(executions) { (executions**2).seconds + rand(1..4).seconds },
    attempts: 8

  good_job_control_concurrency_with(
    key: -> { "heartbeat_import_source_sync_job_#{arguments.first}" },
    total_limit: 1
  )

  def perform(source_id)
    return unless Flipper.enabled?(:wakatime_imports_mirrors)

    source = HeartbeatImportSource.find_by(id: source_id)
    return unless source&.sync_enabled?
    return if source.paused?

    initialize_backfill_if_needed(source)

    if source.backfilling?
      schedule_backfill_window(source)
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
      last_error_at: Time.current,
      consecutive_failures: source.consecutive_failures.to_i + 1
    )
  rescue WakatimeCompatibleClient::TransientError => e
    source&.update!(
      status: source&.backfilling? ? :backfilling : :failed,
      last_error_message: e.message.to_s.truncate(500),
      last_error_at: Time.current,
      consecutive_failures: source.consecutive_failures.to_i + 1
    )
    raise
  rescue WakatimeCompatibleClient::RequestError => e
    source&.update!(
      status: :failed,
      last_error_message: e.message.to_s.truncate(500),
      last_error_at: Time.current,
      consecutive_failures: source.consecutive_failures.to_i + 1
    )
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
      begin
        start_date = source.client.fetch_all_time_since_today_start_date
      rescue => e
        Rails.logger.error("Failed to fetch all_time_since_today for source #{source.id}: #{e.message}")
        source.update!(status: :failed, last_error_message: e.message, last_error_at: Time.current)
        return
      end
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

  def schedule_backfill_window(source)
    cursor = source.backfill_cursor_date
    end_date = source.initial_backfill_end_date || Date.current
    return if cursor.blank?

    if cursor > end_date
      source.update!(status: :syncing, backfill_cursor_date: nil)
      self.class.perform_later(source.id)
      return
    end

    window_end = [ cursor + (BACKFILL_WINDOW_DAYS - 1).days, end_date ].min
    (cursor..window_end).each do |date|
      enqueue_day_sync(source, date)
    end

    next_cursor = window_end + 1.day

    if next_cursor > end_date
      source.update!(status: :syncing, backfill_cursor_date: nil)
      self.class.perform_later(source.id)
    else
      source.update!(status: :backfilling, backfill_cursor_date: next_cursor)
      self.class.perform_later(source.id)
    end
  end

  def enqueue_day_sync(source, date)
    HeartbeatImportSourceSyncDayJob.perform_later(source.id, date.iso8601)
  end
end
