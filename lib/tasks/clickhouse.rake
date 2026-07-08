namespace :clickhouse do
  desc "Backfill the ClickHouse heartbeats table from Postgres (dev/test only). " \
       "Optionally limit to one user: rake clickhouse:backfill_heartbeats[123]"
  task :backfill_heartbeats, [ :user_id ] => :environment do |_t, args|
    abort "Refusing to backfill outside development/test" unless Rails.env.development? || Rails.env.test?

    scope = Heartbeat.with_deleted
    scope = scope.where(user_id: args[:user_id]) if args[:user_id].present?

    total = scope.count
    puts "Backfilling #{total} heartbeats into ClickHouse..."
    Clickhouse::HeartbeatMirror.with_mirroring do
      Clickhouse::HeartbeatMirror.backfill(scope)
    end
    puts "Done. ClickHouse now has #{Clickhouse::Heartbeat.unscoped.final.count} deduped rows."
  end
end
