require "test_helper"

class WakatimeServiceTest < Minitest::Test
  # Since parse_user_agent is a pure function that doesn't need database access,
  # we can test it without loading any fixtures
  def setup
    ActiveRecord::FixtureSet.reset_cache
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

  def test_generate_summary_preserves_requested_end_timestamp
    start_time = Time.utc(2026, 2, 20, 17, 30, 0)
    end_time = Time.utc(2026, 2, 27, 17, 30, 0)

    original_summary = StatsClient.method(:summary)
    StatsClient.singleton_class.send(:define_method, :summary) do |**_args|
      {
        "start_time" => start_time.to_i,
        "end_time" => end_time.to_f - 1e-6,
        "total_seconds" => 120,
        "groups" => {}
      }
    end

    begin
      summary = WakatimeService.new(
        start_date: start_time,
        end_date: end_time
      ).generate_summary

      assert_equal "2026-02-27T17:30:00Z", summary[:end]
    ensure
      StatsClient.singleton_class.send(:define_method, :summary, original_summary)
    end
  end
end
