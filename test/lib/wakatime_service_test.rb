require "test_helper"

class WakatimeServiceTest < ActiveSupport::TestCase
  # Since parse_user_agent is a pure function that doesn't need database access,
  # we can test it without loading any fixtures
  def setup
    ActiveRecord::FixtureSet.reset_cache
    Rails.cache.clear
  end

  def test_parse_user_agent_with_vscode_wakatime_client
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 vscode/1.0.0 vscode-wakatime/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "darwin", result[:os]
    assert_equal "vscode", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_GitHub_Desktop
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 github-desktop/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "darwin", result[:os]
    assert_equal "github-desktop", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_Figma
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 figma/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "darwin", result[:os]
    assert_equal "figma", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_Terminal
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 terminal/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "darwin", result[:os]
    assert_equal "terminal", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_vim
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 vim/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "darwin", result[:os]
    assert_equal "vim", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_Windows
    user_agent = "wakatime/v1.0.0 (windows-x86_64) go1.0.0 vscode/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "windows", result[:os]
    assert_equal "vscode", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_Cursor
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 cursor/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "darwin", result[:os]
    assert_equal "cursor", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_Firefox
    user_agent = "Firefox/139.0 linux_x86-64 firefox-wakatime/4.1.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "linux", result[:os]
    assert_equal "firefox", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_invalid_user_agent
    user_agent = "invalid-user-agent"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "", result[:os]
    assert_equal "", result[:editor]
    assert_equal "failed to parse user agent string", result[:err]
  end

  test "defaults summary range to the scoped user's heartbeats" do
    stale_user = User.create!(username: "stale_#{SecureRandom.hex(3)}", timezone: "UTC")
    recent_user = User.create!(username: "recent_#{SecureRandom.hex(3)}", timezone: "UTC")

    Heartbeat.create!(
      user: stale_user,
      source_type: :direct_entry,
      time: Time.utc(2024, 1, 1, 10, 0, 0).to_f,
      project: "legacy",
      category: "coding"
    )
    Heartbeat.create!(
      user: recent_user,
      source_type: :direct_entry,
      time: Time.utc(2026, 1, 1, 10, 0, 0).to_f,
      project: "new-hotness",
      category: "coding"
    )

    summary = WakatimeService.new(user: stale_user, specific_filters: [], allow_cache: false).generate_summary

    assert_equal "2024-01-01T10:00:00Z", summary[:start]
    assert_equal "2024-01-01T10:00:00Z", summary[:end]
  end

  test "test wakatime service defaults summary range to the scoped user's heartbeats" do
    stale_user = User.create!(username: "test_stale_#{SecureRandom.hex(3)}", timezone: "UTC")
    recent_user = User.create!(username: "test_recent_#{SecureRandom.hex(3)}", timezone: "UTC")

    Heartbeat.create!(
      user: stale_user,
      source_type: :direct_entry,
      time: Time.utc(2024, 2, 2, 8, 0, 0).to_f,
      project: "legacy-test",
      category: "coding"
    )
    Heartbeat.create!(
      user: recent_user,
      source_type: :direct_entry,
      time: Time.utc(2026, 2, 2, 8, 0, 0).to_f,
      project: "new-test",
      category: "coding"
    )

    summary = TestWakatimeService.new(user: stale_user, specific_filters: [], allow_cache: false).generate_summary

    assert_equal "2024-02-02T08:00:00Z", summary[:start]
    assert_equal "2024-02-02T08:00:00Z", summary[:end]
  end

  test "cached summary invalidates when an older heartbeat is inserted later" do
    user = User.create!(username: "cache_insert_#{SecureRandom.hex(3)}", timezone: "UTC")

    Heartbeat.create!(
      user: user,
      source_type: :direct_entry,
      time: Time.utc(2026, 3, 1, 12, 0, 0).to_f,
      project: "current",
      category: "coding"
    )

    first_summary = WakatimeService.new(user: user, specific_filters: [], allow_cache: true).generate_summary
    assert_equal "2026-03-01T12:00:00Z", first_summary[:start]

    Heartbeat.create!(
      user: user,
      source_type: :direct_entry,
      time: Time.utc(2025, 3, 1, 12, 0, 0).to_f,
      project: "backfill",
      category: "coding"
    )

    second_summary = WakatimeService.new(user: user, specific_filters: [], allow_cache: true).generate_summary
    assert_equal "2025-03-01T12:00:00Z", second_summary[:start]
  end

  test "cached summary invalidates after imported backfill heartbeats" do
    user = User.create!(username: "cache_import_#{SecureRandom.hex(3)}", timezone: "UTC")

    Heartbeat.create!(
      user: user,
      source_type: :direct_entry,
      time: Time.utc(2026, 4, 1, 12, 0, 0).to_f,
      project: "current",
      category: "coding"
    )

    first_summary = WakatimeService.new(user: user, specific_filters: [], allow_cache: true).generate_summary
    assert_equal "2026-04-01T12:00:00Z", first_summary[:start]

    file_content = {
      heartbeats: [
        {
          entity: "/tmp/older.rb",
          type: "file",
          time: Time.utc(2025, 4, 1, 12, 0, 0).to_f,
          project: "backfill-import",
          language: "Ruby",
          category: "coding",
          is_write: true
        }
      ]
    }.to_json

    result = HeartbeatImportService.import_from_file(file_content, user)
    assert result[:success]

    second_summary = WakatimeService.new(user: user, specific_filters: [], allow_cache: true).generate_summary
    assert_equal "2025-04-01T12:00:00Z", second_summary[:start]
  end
end
