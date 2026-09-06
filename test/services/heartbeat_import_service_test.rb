require "test_helper"

class HeartbeatImportServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "a malformed dump after a committed batch still invalidates rollups" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    user = create(:user)
    create(:heartbeat, user: user, time: 1_800_000_000.0)
    DashboardRollupRefreshService.new(user: user).call
    clear_enqueued_jobs
    Rails.cache.clear
    row = { entity: "old.rb", time: 1_700_000_000.0, type: "file" }.to_json
    truncated_dump = '{"heartbeats":[' + ([ row ] * HeartbeatImportService::BATCH_SIZE).join(",") + ',{"entity":'

    result = HeartbeatImportService.import_from_file(StringIO.new(truncated_dump), user)

    assert_not result[:success]
    assert_equal 1, result[:imported_count]
    assert_equal 2, user.heartbeats.count
    assert DashboardRollup.dirty?(user.id)
    assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ])
  ensure
    Rails.cache = original_cache
  end

  test "sanitizes null bytes without losing valid batch rows and deduplicates replays" do
    user = create(:user)
    rows = [
      { entity: "first.rb", project: "api", time: 1_700_000_000.0, type: "file" },
      { entity: "sec\0ond.rb", project: "api", branch: "ma\0in", dependencies: [ "ra\0ils" ], time: 1_700_000_060.0, type: "file" }
    ]

    result = HeartbeatImportService.import_from_file(StringIO.new({ heartbeats: rows }.to_json), user)
    assert result[:success], result[:error]
    assert_equal 2, result[:imported_count]
    heartbeat = user.heartbeats.find_by!(entity: "second.rb")
    assert_equal "main", heartbeat.branch
    assert_equal [ "rails" ], heartbeat.dependencies

    sanitized = [ rows.first, rows.second.merge(entity: "second.rb", branch: "main", dependencies: [ "rails" ]) ]
    [ rows, sanitized ].each do |replay|
      result = HeartbeatImportService.import_from_file({ heartbeats: replay }.to_json, user)
      assert result[:success], result[:error]
      assert_equal 0, result[:imported_count]
    end
    assert_equal 2, user.heartbeats.count
  end

  test "deduplicates imported heartbeats by fields hash" do
    user = create(:user)
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
    user = create(:user)
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

  test "normalizes and validates each imported heartbeat once" do
    user = create(:user)
    validation_count = 0
    validation = lambda do |_heartbeat|
      validation_count += 1
    end
    Heartbeat.set_callback(:validate, :before, validation)

    begin
      result = HeartbeatImportService.import_from_file(
        { heartbeats: [ { entity: "/tmp/test.rb", time: 1_700_000_000.0, type: "file" } ] }.to_json,
        user
      )

      assert result[:success]
      assert_equal 1, validation_count
    ensure
      Heartbeat.skip_callback(:validate, :before, validation)
    end
  end

  test "re-importing placeholders is idempotent after database context changes" do
    user = create(:user)
    file_content = {
      heartbeats: [
        {
          branch: "<<LAST_BRANCH>>",
          entity: "notes",
          language: "<<LAST_LANGUAGE>>",
          project: "api",
          time: 1_700_000_000.0,
          type: "file"
        },
        {
          branch: "main",
          entity: "b.rb",
          language: "Ruby",
          project: "api",
          time: 1_700_000_001.0,
          type: "file"
        }
      ]
    }.to_json

    first = HeartbeatImportService.import_from_file(file_content, user)
    second = HeartbeatImportService.import_from_file(file_content, user)

    assert_equal 2, first[:imported_count]
    assert_equal 0, second[:imported_count]
    assert_equal 2, second[:skipped_count]
    assert_equal 2, user.heartbeats.count
  end
end
