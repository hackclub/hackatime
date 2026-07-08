# Moves heartbeats between users during an account merge. Heartbeats live only
# in ClickHouse; the copy + tombstone statements are idempotent (identical
# ORDER BY key and version rows collapse under ReplacingMergeTree), so retries
# are safe.
class AccountMergeHeartbeatsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(older_user_id, newer_user_id)
    Clickhouse::HeartbeatWriter.merge_user_heartbeats!(older_user_id: older_user_id, newer_user_id: newer_user_id)
  end
end
