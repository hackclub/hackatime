class BackfillHeartbeatDimensionsJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    key: -> { "backfill_heartbeat_dimensions_#{arguments.first}" },
    total_limit: 1
  )

  BATCH_SIZE = 5_000

  def perform(dimension, start_id: 0, end_id: nil)
    spec = HeartbeatDimensionResolver::DIMENSIONS[dimension.to_sym]
    unless spec
      Rails.logger.error("Invalid dimension: #{dimension}")
      return
    end

    end_id ||= Heartbeat.with_deleted.maximum(:id) || 0
    current_id = start_id
    processed = 0

    while current_id <= end_id
      batch_end = current_id + BATCH_SIZE
      model = spec[:model].constantize

      processed += if spec[:scope] == :global
        backfill_global_dimension(model, spec[:value_attr], spec[:fk], spec[:lookup], current_id, batch_end)
      else
        backfill_user_scoped_dimension(model, spec[:value_attr], spec[:fk], current_id, batch_end)
      end

      current_id = batch_end
      sleep(0.1)
    end

    Rails.logger.info("BackfillHeartbeatDimensionsJob: #{dimension} complete, processed #{processed} rows")
  end

  private

  def backfill_global_dimension(model, string_column, fk_column, lookup_column, start_id, end_id)
    heartbeats = Heartbeat.with_deleted
                          .where(id: start_id...end_id)
                          .where(fk_column => nil)
                          .where.not(string_column => nil)

    values = heartbeats.distinct.pluck(string_column).compact
    return 0 if values.empty?

    now = Time.current
    rows = values.map { |v| { lookup_column => v, created_at: now, updated_at: now } }
    model.upsert_all(rows, unique_by: lookup_column)

    lookup_map = model.where(lookup_column => values).pluck(lookup_column, :id).to_h

    updated = 0
    lookup_map.each do |value, id|
      updated += Heartbeat.with_deleted
                          .where(id: start_id...end_id)
                          .where(fk_column => nil)
                          .where(string_column => value)
                          .update_all(fk_column => id)
    end
    updated
  end

  def backfill_user_scoped_dimension(model, string_column, fk_column, start_id, end_id)
    heartbeats = Heartbeat.with_deleted
                          .where(id: start_id...end_id)
                          .where(fk_column => nil)
                          .where.not(string_column => nil)

    user_value_pairs = heartbeats.distinct.pluck(:user_id, string_column).select { |u, v| u && v }
    return 0 if user_value_pairs.empty?

    now = Time.current
    rows = user_value_pairs.map { |user_id, name| { user_id: user_id, name: name, created_at: now, updated_at: now } }
    model.upsert_all(rows, unique_by: [ :user_id, :name ])

    lookup_map = model.where([ "(user_id, name) IN (?)", user_value_pairs ])
                      .pluck(:user_id, :name, :id)
                      .each_with_object({}) { |(uid, name, id), h| h[[ uid, name ]] = id }

    updated = 0
    lookup_map.each do |(user_id, name), id|
      updated += Heartbeat.with_deleted
                          .where(id: start_id...end_id)
                          .where(fk_column => nil)
                          .where(user_id: user_id)
                          .where(string_column => name)
                          .update_all(fk_column => id)
    end
    updated
  end
end
