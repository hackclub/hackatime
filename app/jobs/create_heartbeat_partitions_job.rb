class CreateHeartbeatPartitionsJob < ApplicationJob
  queue_as :literally_whenever

  MONTHS_AHEAD = 3

  def perform
    conn = ActiveRecord::Base.connection

    MONTHS_AHEAD.times do |i|
      date = (Time.current + (i + 1).months).beginning_of_month
      partition_name = "heartbeats_#{date.strftime('%Y_%m')}"

      next if partition_exists?(conn, partition_name)

      from_ts = date.utc.to_i
      to_ts = (date + 1.month).utc.to_i

      # CONCURRENTLY cannot run inside a transaction, so each step is separate.
      # This avoids ACCESS EXCLUSIVE locks that would block reads/writes.
      conn.execute("ALTER TABLE heartbeats DETACH PARTITION heartbeats_default CONCURRENTLY")
      conn.execute("CREATE TABLE #{partition_name} PARTITION OF heartbeats FOR VALUES FROM (#{from_ts}) TO (#{to_ts})")
      conn.execute("ALTER TABLE heartbeats ATTACH PARTITION heartbeats_default FOR VALUES FROM (#{to_ts}) TO (MAXVALUE)")

      Rails.logger.info("Created heartbeat partition: #{partition_name}")
    end
  end

  private

  def partition_exists?(conn, name)
    conn.select_value("SELECT 1 FROM pg_class WHERE relname = #{conn.quote(name)}").present?
  end
end
