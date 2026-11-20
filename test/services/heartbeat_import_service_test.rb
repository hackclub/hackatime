require "test_helper"

class HeartbeatImportServiceTest < ActiveSupport::TestCase
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

  test "resolves wakatime ids, imports recent heartbeats and does not duplicate rows imported without the lookups" do
    user = create(:user)
    user_agent = "wakatime/v1.102.1 (darwin-24.6.0-arm64) go1.22.0 vscode/1.95.0 vscode-wakatime/24.0.0"
    exported = { entity: "/code/app.rb", type: "file", time: 1_727_905_177.5, category: "coding", project: "app",
                 language: "Ruby", machine_name_id: "machine-1", user_agent_id: "ua-1", is_write: true }
    recent = exported.merge(entity: "/code/recent.rb", time: 1_727_995_177.5)
    file_content = { days: [ { date: "2024-10-02", heartbeats: [ exported ] } ] }.to_json

    HeartbeatImportService.import_from_file(file_content, user)
    assert_equal [ [ "machine-1", "ua-1" ] ], user.heartbeats.pluck(:machine, :user_agent)

    result = HeartbeatImportService.import_from_file(
      file_content, user,
      user_agents_by_id: { "ua-1" => { "value" => user_agent, "editor" => "VS Code", "os" => "Mac" } },
      machine_names_by_id: { "machine-1" => "mahads-macbook" },
      extra_heartbeats: [ recent.deep_stringify_keys, exported.deep_stringify_keys ]
    )

    assert result[:success]
    assert_equal 3, result[:total_count]
    assert_equal 1, result[:imported_count]
    assert_equal 2, user.heartbeats.count
    heartbeat = user.heartbeats.find_by!(entity: "/code/recent.rb")
    assert_equal [ "mahads-macbook", user_agent, "VS Code", "Mac" ],
      [ heartbeat.machine, heartbeat.user_agent, heartbeat.editor, heartbeat.operating_system ]
  end

  test "does not duplicate pre-normalization rows whose user agent id now resolves" do
    user = create(:user)
    exported = { entity: "/code/app.rb", type: "file", time: 1_727_905_177.5, category: "", project: "app",
                 language: "", machine_name_id: "machine-1", user_agent_id: "ua-on-page-2", is_write: true }
    # Pre-#1478 hash with the raw user agent id.
    legacy_attrs = {
      user_id: user.id, time: exported[:time], entity: exported[:entity], type: "file", category: "",
      project: "app", language: "Ruby", editor: nil, operating_system: nil, machine: "machine-1", branch: nil,
      user_agent: "ua-on-page-2", is_write: true, line_additions: nil, line_deletions: nil, lineno: nil,
      lines: nil, cursorpos: nil, dependencies: [], project_root_count: nil
    }
    user.heartbeats.create!(legacy_attrs.merge(source_type: :wakapi_import, fields_hash: Heartbeat.generate_fields_hash(legacy_attrs)))

    result = HeartbeatImportService.import_from_file(
      { days: [ { date: "2024-10-02", heartbeats: [ exported ] } ] }.to_json, user,
      user_agents_by_id: { "ua-on-page-2" => { "value" => "wakatime/v1.102.1 (darwin-arm64) go1.22.0 vscode/1.95.0", "editor" => "VS Code", "os" => "Mac" } },
      machine_names_by_id: { "machine-1" => "mahads-macbook" }
    )

    assert result[:success]
    assert_equal 0, result[:imported_count]
    assert_equal 1, user.heartbeats.count
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
