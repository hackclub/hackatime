require 'spec_helper'
# Force (not ||=): the dev container exports RAILS_ENV=development
ENV['RAILS_ENV'] = 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true, allow: [ ENV.fetch("CLICKHOUSE_HOST", "clickhouse") ])
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!

  # ClickHouse inserts are not rolled back with the per-example PG
  # transaction; reset the heartbeats table to exactly the seeded rows.
  config.before(:each) do
    connection = Clickhouse::Heartbeat.connection
    connection.execute("TRUNCATE TABLE heartbeats")
    rows = $clickhouse_seed_heartbeats
    Clickhouse::Heartbeat.unscoped.insert_all(rows) if rows.present?
  end

  config.before(:suite) do
    Clickhouse::Heartbeat.connection.execute("TRUNCATE TABLE heartbeats")
    Rails.application.load_seed
    columns = Clickhouse::HeartbeatWriter::WRITABLE_COLUMNS
    $clickhouse_seed_heartbeats = Clickhouse::Heartbeat.unscoped.final
      .select(*columns).map { |row| row.attributes.slice(*columns) }
    ENV['STATS_API_KEY'] = 'dev-api-key-12345'
  end
end
