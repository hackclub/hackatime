class HeartbeatImportSourceSyncDayJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  retry_on WakatimeCompatibleClient::TransientError,
    wait: ->(executions) { (executions**2).seconds + rand(1..4).seconds },
    attempts: 8

  good_job_control_concurrency_with(
    key: -> { "heartbeat_import_source_sync_day_job_#{arguments.first}_#{arguments.second}" },
    total_limit: 1
  )

  def perform(source_id, date_string)
    source = HeartbeatImportSource.find_by(id: source_id)
    return unless source&.sync_enabled?

    date = Date.iso8601(date_string)
    rows = source.client.fetch_heartbeats(date:)
    upsert_heartbeats(source.user_id, rows)

    source.update!(
      last_synced_at: Time.current,
      last_error_message: nil,
      last_error_at: nil,
      consecutive_failures: 0
    )
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
  rescue ArgumentError => e
    source&.update!(
      status: :failed,
      last_error_message: e.message.to_s.truncate(500),
      last_error_at: Time.current,
      consecutive_failures: source.consecutive_failures.to_i + 1
    )
  end

  private

  def upsert_heartbeats(user_id, rows)
    normalized = rows.filter_map { |row| normalize_row(user_id, row) }
    return if normalized.empty?

    deduped_records = normalized.group_by { |record| record[:fields_hash] }.map do |_, records|
      records.max_by { |record| record[:time].to_f }
    end

    Heartbeat.upsert_all(deduped_records, unique_by: [ :fields_hash ])
  end

  def normalize_row(user_id, row)
    data = row.respond_to?(:with_indifferent_access) ? row.with_indifferent_access : row.to_h.with_indifferent_access
    timestamp = extract_timestamp(data)
    return nil if timestamp.blank?

    attrs = {
      user_id: user_id,
      branch: value_or_nil(data[:branch]),
      category: value_or_nil(data[:category]) || "coding",
      dependencies: extract_dependencies(data[:dependencies]),
      editor: value_or_nil(data[:editor]),
      entity: value_or_nil(data[:entity]),
      language: value_or_nil(data[:language]),
      machine: value_or_nil(data[:machine]),
      operating_system: value_or_nil(data[:operating_system]),
      project: value_or_nil(data[:project]),
      type: value_or_nil(data[:type]),
      user_agent: value_or_nil(data[:user_agent]),
      line_additions: data[:line_additions],
      line_deletions: data[:line_deletions],
      lineno: data[:lineno],
      lines: data[:lines],
      cursorpos: data[:cursorpos],
      project_root_count: data[:project_root_count],
      time: timestamp,
      is_write: ActiveModel::Type::Boolean.new.cast(data[:is_write]),
      source_type: :wakapi_import
    }

    now = Time.current
    attrs[:created_at] = now
    attrs[:updated_at] = now
    attrs[:fields_hash] = Heartbeat.generate_fields_hash(attrs)
    attrs
  rescue TypeError, JSON::ParserError
    nil
  end

  def extract_dependencies(value)
    return value if value.is_a?(Array)
    return [] if value.blank?

    JSON.parse(value.to_s)
  rescue JSON::ParserError
    value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def extract_timestamp(data)
    value = data[:time]
    value = data[:created_at] if value.blank?
    return nil if value.blank?

    if value.is_a?(Numeric)
      normalized = value.to_f
      return (normalized / 1000.0) if normalized > 1_000_000_000_000

      return normalized
    end

    parsed = Time.parse(value.to_s).to_f
    return parsed if parsed.positive?

    nil
  rescue ArgumentError
    nil
  end

  def value_or_nil(value)
    return nil if value.nil?
    return value.strip.presence if value.is_a?(String)

    value
  end
end
