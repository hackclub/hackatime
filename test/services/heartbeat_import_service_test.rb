require "test_helper"

class HeartbeatImportServiceTest < ActiveSupport::TestCase
  test "deduplicates imported heartbeats by fields hash" do
    user = User.create!(timezone: "UTC")
    file_content = {
      heartbeats: [
        {
          entity: "/tmp/test.rb",
          type: "file",
          time: 1_700_000_000.0,
          project: "hackatime",
          language: "Ruby",
          is_write: true
        },
        {
          entity: "/tmp/test.rb",
          type: "file",
          time: 1_700_000_000.0,
          project: "hackatime",
          language: "Ruby",
          is_write: true
        }
      ]
    }.to_json

    result = HeartbeatImportService.import_from_file(file_content, user)

    assert result[:success]
    assert_equal 2, result[:total_count]
    assert_equal 1, result[:imported_count]
    assert_equal 1, result[:skipped_count]
    assert_equal 1, Clickhouse::Heartbeat.for_user(user).count
  end

  test "pre-batch dedupe keeps the latest heartbeat for a duplicate fields hash" do
    user = User.create!(timezone: "UTC")
    captured_heartbeats = nil
    file_content = {
      heartbeats: [
        { entity: "/tmp/newer.rb", time: 1_700_000_200.0 },
        { entity: "/tmp/older.rb", time: 1_700_000_100.0 }
      ]
    }.to_json

    original_normalizer = HeartbeatIngest.method(:normalize_imported_heartbeat)
    original_call = HeartbeatIngest.method(:call)
    HeartbeatIngest.define_singleton_method(:normalize_imported_heartbeat) do |user:, heartbeat:, user_agents_by_id: {}|
      { fields_hash: "duplicate-hash", time: heartbeat.fetch("time") }
    end
    HeartbeatIngest.define_singleton_method(:call) do |user:, mode:, heartbeats:, user_agents_by_id: {}|
      captured_heartbeats = heartbeats
      HeartbeatIngest::Result.new(total_count: heartbeats.length, persisted_count: heartbeats.length,
        duplicate_count: 0, failed_count: 0, errors: [], items: [])
    end

    result = HeartbeatImportService.import_from_file(file_content, user)

    assert result[:success]
    assert_equal 2, result[:total_count]
    assert_equal 1, result[:imported_count]
    assert_equal [ 1_700_000_200.0 ], captured_heartbeats.map { |heartbeat| heartbeat.fetch("time") }
  ensure
    HeartbeatIngest.define_singleton_method(:normalize_imported_heartbeat, original_normalizer) if original_normalizer
    HeartbeatIngest.define_singleton_method(:call, original_call) if original_call
  end

  test "imports heartbeats from wakatime data dump day groups" do
    user = User.create!(timezone: "UTC")
    file_content = {
      range: { start: 1_727_905_169, end: 1_727_905_177 },
      days: [
        {
          date: "2024-10-02",
          heartbeats: [
            {
              entity: "/home/skyfall/tavern/manifest.json",
              type: "file",
              time: 1_727_905_177,
              category: "coding",
              project: "tavern",
              language: "JSON",
              editor: "vscode",
              operating_system: "Linux",
              machine_name_id: "skyfall-pc",
              user_agent_id: "wakatime/v1.102.1",
              is_write: true
            }
          ]
        }
      ]
    }.to_json

    result = HeartbeatImportService.import_from_file(file_content, user)

    assert result[:success]
    assert_equal 1, result[:total_count]
    assert_equal 1, result[:imported_count]

    heartbeat = Clickhouse::Heartbeat.for_user(user).order(:created_at).last
    assert_equal "skyfall-pc", heartbeat.machine
    assert_equal "wakatime/v1.102.1", heartbeat.user_agent
  end
end
