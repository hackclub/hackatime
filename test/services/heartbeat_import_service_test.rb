require "test_helper"

class HeartbeatImportServiceTest < ActiveSupport::TestCase
  def setup
    Rails.cache.clear
  end

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
    assert_equal 1, user.heartbeats.count
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

    heartbeat = user.heartbeats.order(:created_at).last
    assert_equal "skyfall-pc", heartbeat.machine
    assert_equal "wakatime/v1.102.1", heartbeat.user_agent
  end

  test "bumps the user's heartbeat cache version when new rows are imported" do
    user = User.create!(timezone: "UTC")
    initial_version = HeartbeatCacheInvalidator.version_for(user)

    result = HeartbeatImportService.import_from_file({
      heartbeats: [
        {
          entity: "/tmp/imported.rb",
          type: "file",
          time: Time.utc(2026, 1, 1, 10, 0, 0).to_f,
          project: "cache-test",
          category: "coding"
        }
      ]
    }.to_json, user)

    assert result[:success]
    assert_equal initial_version + 1, HeartbeatCacheInvalidator.version_for(user)
  end
end
