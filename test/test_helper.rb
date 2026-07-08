ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "nokogiri"
require "json"

module ClickhouseTestIsolation
  def before_setup
    Clickhouse::Heartbeat.connection.execute("TRUNCATE TABLE heartbeats")
    super
  end
end

# Heartbeats live only in ClickHouse. Tests create them through the writer and
# get back a readonly-ish Clickhouse::Heartbeat instance.
module ClickhouseHeartbeatFactory
  def create_heartbeat(user: nil, user_id: nil, **attrs)
    user_id ||= user.respond_to?(:id) ? user.id : user
    raise ArgumentError, "create_heartbeat requires user: or user_id:" if user_id.nil?

    row = Clickhouse::HeartbeatWriter.create!(attrs.merge(user_id: user_id))
    Clickhouse::Heartbeat.instantiate(row.transform_values { |v| v.is_a?(Symbol) ? v.to_s : v })
  end

  # Soft delete = insert a tombstone version of the row.
  def soft_delete_heartbeat(heartbeat)
    now = Time.current
    Clickhouse::HeartbeatWriter.insert_rows([
      heartbeat.attributes.slice(*Clickhouse::HeartbeatWriter::WRITABLE_COLUMNS)
        .merge("deleted_at" => now, "updated_at" => now, "version" => (now.to_f * 1_000_000).round)
    ])
  end

  # Restore = insert a live version with a bumped version.
  def restore_heartbeat(heartbeat)
    now = Time.current
    Clickhouse::HeartbeatWriter.insert_rows([
      heartbeat.attributes.slice(*Clickhouse::HeartbeatWriter::WRITABLE_COLUMNS)
        .merge("deleted_at" => nil, "updated_at" => now, "version" => (now.to_f * 1_000_000).round)
    ])
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 2).to_i)

    CLICKHOUSE_BASE_DATABASE = Clickhouse::Record.connection_db_config.database

    # Rails' TestDatabases after_fork hook has already suffixed the config's
    # database with the worker number; build the name from the pre-fork base
    # so this doesn't double-suffix.
    parallelize_setup do |worker|
      db = "#{CLICKHOUSE_BASE_DATABASE}_#{worker}"
      base_config = Clickhouse::Record.connection_db_config.configuration_hash.merge(database: CLICKHOUSE_BASE_DATABASE)
      Clickhouse::Record.establish_connection(base_config)
      Clickhouse::Record.connection.execute("DROP DATABASE IF EXISTS #{db}")
      Clickhouse::Record.connection.execute("CREATE DATABASE #{db}")
      Clickhouse::Record.establish_connection(base_config.merge(database: db))
      File.read(Rails.root.join("db/clickhouse_structure.sql")).split(";\n\n").each do |statement|
        Clickhouse::Record.connection.execute(statement, nil, format: nil) if statement.strip.present?
      end
    end

    include ClickhouseTestIsolation
    include ClickhouseHeartbeatFactory

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    self.fixture_table_names -= [
      "mailing_addresses",
      "physical_mails",
      "api_keys",
      "heartbeats",
      "users",
      "email_addresses",
      "project_repo_mappings",
      "repositories",
      "sailors_log_leaderboards",
      "sailors_log_notification_preferences",
      "sailors_log_slack_notifications",
      "sailors_logs"
    ]

    # Add more helper methods to be used by all tests here...
  end
end

module SystemTestAuthHelper
  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    visit auth_token_path(token: token.token)
  end
end

module IntegrationTestAuthHelper
  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]
  end
end

module InertiaTestHelper
  def inertia_page
    document = Nokogiri::HTML(response.body)
    page_script = document.at_css("script[data-page='app'][type='application/json']")
    assert_not_nil page_script, "Expected Inertia page payload script in response body"
    JSON.parse(page_script.text)
  end

  def assert_inertia_component(expected_component)
    page = inertia_page
    assert_equal expected_component, page["component"],
      "Expected Inertia component '#{expected_component}' but got '#{page["component"]}'"
  end

  def assert_inertia_prop(key, expected_value)
    page = inertia_page
    actual = page.dig("props", key)
    if expected_value.nil?
      assert_nil actual, "Expected Inertia prop '#{key}' to be nil but got #{actual.inspect}"
    else
      assert_equal expected_value, actual,
        "Expected Inertia prop '#{key}' to be #{expected_value.inspect} but got #{actual.inspect}"
    end
  end
end

class ActionDispatch::IntegrationTest
  include IntegrationTestAuthHelper
  include InertiaTestHelper
end
