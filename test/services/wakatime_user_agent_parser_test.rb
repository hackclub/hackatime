require "test_helper"

class WakatimeUserAgentParserTest < Minitest::Test
  def test_parse_user_agent_with_vscode_wakatime_client
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 vscode/1.0.0 vscode-wakatime/1.0.0"
    result = WakatimeUserAgentParser.parse(user_agent)
    assert_equal "macos", result[:os]
    assert_equal "vscode", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_without_a_runtime_token
    result = WakatimeUserAgentParser.parse(
      "wakatime/1.0 (linux-x86_64) vscode/1.90"
    )

    assert_equal "linux", result[:os]
    assert_equal "vscode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_without_products_after_the_platform
    result = WakatimeUserAgentParser.parse(
      "wakatime/v1.86.0 (windows-10.0.22631-x86_64)"
    )

    assert_equal "windows", result[:os]
    assert_equal "", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_with_GitHub_Desktop
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 github-desktop/1.0.0"
    result = WakatimeUserAgentParser.parse(user_agent)
    assert_equal "macos", result[:os]
    assert_equal "github-desktop", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_with_Figma
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 figma/1.0.0"
    result = WakatimeUserAgentParser.parse(user_agent)
    assert_equal "macos", result[:os]
    assert_equal "figma", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_with_Terminal
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 terminal/1.0.0"
    result = WakatimeUserAgentParser.parse(user_agent)
    assert_equal "macos", result[:os]
    assert_equal "terminal", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_with_vim
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 vim/1.0.0"
    result = WakatimeUserAgentParser.parse(user_agent)
    assert_equal "macos", result[:os]
    assert_equal "vim", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_with_Windows
    user_agent = "wakatime/v1.0.0 (windows-x86_64) go1.0.0 vscode/1.0.0"
    result = WakatimeUserAgentParser.parse(user_agent)
    assert_equal "windows", result[:os]
    assert_equal "vscode", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_with_Cursor
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 cursor/1.0.0"
    result = WakatimeUserAgentParser.parse(user_agent)
    assert_equal "macos", result[:os]
    assert_equal "cursor", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_separates_ai_model_from_claude_code_editor
    user_agent = "wakatime/v2.21.4 (darwin-25.5.0-arm64) go1.26.4 opus/4-8 claude-code/2.1.202"

    result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

    assert_equal "macos", result[:os]
    assert_equal "claude-code", result[:editor]
    assert_equal "opus/4-8", result[:ai_model]
  end

  def test_parse_user_agent_separates_ai_model_from_copilot_cli_editor
    user_agent = "wakatime/v2.21.4 (windows-10.0.19045.5011-x86_64) go1.26.4 gpt/5.3-codex github-copilot-cli/1.0.68 copilot/1.0.68 cursor/1.105.1 vscode-wakatime/30.2.1"

    result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

    assert_equal "windows", result[:os]
    assert_equal "copilot-cli", result[:editor]
    assert_equal "gpt/5.3-codex", result[:ai_model]
  end

  def test_parse_user_agent_prefers_specific_editor_evidence_after_the_model
    vscode = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 gpt/5.6 vscode-wakatime/unknown Zed/1.11.3 Zed-hackatime/0.3.1",
      category: "ai coding"
    )
    opencode = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 fable/5 opencode-cli/local Zed/1.11.3 Zed-hackatime/0.3.1",
      category: "ai coding"
    )

    assert_equal "zed", vscode[:editor]
    assert_equal "gpt/5.6", vscode[:ai_model]
    assert_equal "opencode-cli", opencode[:editor]
    assert_equal "fable/5", opencode[:ai_model]
  end

  def test_parse_user_agent_keeps_ai_agent_prefix_without_a_model
    opencode = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 opencode-cli/local Zed/1.11.3 Zed-hackatime/0.3.1",
      category: "ai coding"
    )
    amp = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 amp/unknown Zed/1.11.3 Zed-hackatime/0.3.1",
      category: "ai coding"
    )

    assert_equal "opencode-cli", opencode[:editor]
    assert_nil opencode[:ai_model]
    assert_equal "amp", amp[:editor]
    assert_nil amp[:ai_model]
  end

  def test_parse_user_agent_keeps_a_leading_legacy_ai_client_before_its_fallback_plugin_chain
    user_agents = [
      "wakatime/v2.14.2 (darwin-24.6.0-arm64) go1.26.3 Codex/0.128.0-alpha.1 Zed/1.2.6+stable.280.20b7f31e7dbe8233a198728ccf3c8aa1180c13e4 Zed-hackatime/0.3.1",
      "wakatime/v2.15.0 (darwin-24.6.0-arm64) go1.26.3 Codex/0.112.0 vscode-wakatime/unknown Zed/1.5.3 Zed-hackatime/0.3.1",
      "wakatime/v2.15.0 (darwin-24.6.0-arm64) go1.26.3 Codex/0.133.0 unknown-wakatime/unknown zsh/5.9 terminal-wakatime/1.1.5"
    ]

    user_agents.each do |user_agent|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

      assert_equal "codex", result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_keeps_an_unversioned_ai_agent_before_a_generic_fallback_plugin
    user_agent = "wakatime/v2.15.0 (darwin-24.6.0-arm64) go1.26.3 OpenCode/local vscode-wakatime/unknown Notes/4.12.7 macos-wakatime/5.28.4"

    result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

    assert_equal "opencode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_recognizes_dot_named_wakatime_plugins
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (linux-x86_64) go1.26.5 neovim/0.12 wakatime.nvim/12.0.0",
      category: "ai coding"
    )

    assert_equal "neovim", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_ignores_parenthesized_plugin_metadata
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.21.4 (linux-x86_64) go1.26.4 VSCodium/1.121.0 (Continue/2.0.0)",
      category: "ai coding"
    )

    assert_equal "vscodium", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_does_not_treat_ai_agent_products_as_models
    user_agents = {
      "wakatime/v2.22.0 (windows-x86_64) go1.26.5 antigravity-desktop/unknown vscode/1.128.0 vscode-wakatime/30.2.1" => "antigravity-desktop",
      "wakatime/v2.21.4 (linux-x86_64) go1.26.4 github-copilot/0.55.0 VSCodium/1.121.0 vscode-wakatime/30.2.1" => "github-copilot",
      "wakatime/v2.14.7 (darwin-arm64) go1.26.3 ClaudeCode/2.1.197 cursor/1.105.1 vscode-wakatime/30.2.1" => "claude-code",
      "wakatime/v2.22.2 (linux-x86_64) go1.26.5 qwen-code-cli/0.17.0 zed/1.11.3 zed-hackatime/0.3.1" => "qwen-code-cli",
      "wakatime/v2.16.1 (linux-x86_64) go1.26.4 OpenCode/1.17.9 opencode-cli/1.17.9 opencode-wakatime/1.3.8" => "opencode"
    }

    user_agents.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")
      assert_equal editor, result[:editor]
      assert_nil result[:ai_model]
    end
  end

  def test_parse_user_agent_recognizes_production_ai_agent_aliases
    user_agents = {
      "wakatime/v2.2.3 (linux-x86_64) go1.25.5 GitHubCopilot/0.43.0 vscode/1.115.0 vscode-wakatime/30.0.5" => "github-copilot",
      "wakatime/v2.14.7 (linux-x86_64) go1.26.3 Cline vscode/1.118.1 vscode-wakatime/30.1.3" => "cline",
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 antigravity/1.107.0 codex vscode-wakatime/29.0.3" => "antigravity"
    }

    user_agents.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

      assert_equal editor, result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_recognizes_multiword_ai_agent_products
    user_agents = {
      "wakatime/v2.21.4 (darwin-arm64) go1.26.4 Oh My Pi/1" => "pi",
      "wakatime/v2.15.3 (darwin-arm64) go1.26.4 Qwen Code/0.14.3 antigravity/1.107.0 vscode-wakatime/30.2.1" => "qwen-code",
      "wakatime/v2.13.0 (linux-x86_64) Roo Code vscode/1.119.0 vscode-wakatime/30.1.3" => "roo-code",
      "wakatime/v1.132.1 (darwin-24.6.0-x86_64) go1.25.5 Factory Droid/1.0.0" => "droid"
    }

    user_agents.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

      assert_equal editor, result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_ignores_a_duplicated_wakatime_header
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.0.12 (windows-10.0.26200.8037-x86_64) go1.25.5 wakatime/v2.0.12 (windows-10.0.26200.8037-x86_64) go1.25.5 claude/2.1.92 claude-code-wakatime/3.1.5 ClaudeCode/2.1.87",
      category: "ai coding"
    )

    assert_equal "claude-code", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_recognizes_a_spaced_vscode_product
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.0 (windows-10.0.26200.8655-x86_64) go1.26.5 (/1) Visual Studio Code/1.127.0 (Continue/2.1.0)",
      category: "ai coding"
    )

    assert_equal "vscode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_keeps_editor_before_a_trailing_bare_ai_agent
    result = WakatimeUserAgentParser.parse(
      "wakatime/v1.139.4 (linux-x86_64) go1.25.5 vscodium/1.110.1 claude vscode-wakatime/29.0.3",
      category: "ai coding"
    )

    assert_equal "vscodium", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_keeps_editor_before_a_trailing_versioned_ai_agent
    user_agents = {
      "wakatime/v2.0.13 (linux-x86_64) go1.25.5 vscodium/1.112.0 vscode-wakatime/30.0.2 ClaudeCode/2.1.87" => "vscodium",
      "wakatime/v2.0.12 (windows-x86_64) go1.25.5 vscodium/1.112.0 vscode-wakatime/30.0.2 Codex/0.118.0-alpha.2" => "vscodium",
      "wakatime/v2.0.12 (linux-x86_64) go1.25.5 code-oss/1.111.0 vscode-wakatime/30.0.4 ClaudeCode/unknown" => "code-oss",
      "wakatime/v2.0.13 (darwin-arm64) go1.25.5 zsh/5.9 terminal-wakatime/dev ClaudeCode/2.1.85" => "zsh",
      "wakatime/v2.0.12 (darwin-arm64) go1.25.5 cursor/1.105.1 vscode-wakatime/30.0.4 Codex/0.118.0-alpha.2" => "cursor",
      "wakatime/v1.131.0 (darwin-arm64) go1.24.4 cursor/1.99.3 vscode-wakatime/25.3.1 waka-relay/0.2.1" => "cursor"
    }

    user_agents.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

      assert_equal editor, result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_keeps_shared_plugin_editor_before_an_inline_agent
    user_agents = {
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 cursor/1.105.1 claude vscode-wakatime/29.0.3" => "cursor",
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 kiro/1.107.1 claude vscode-wakatime/29.0.3" => "kiro",
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 windsurf/1.107.0 codex vscode-wakatime/29.0.3" => "windsurf",
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 antigravity/1.107.0 codex vscode-wakatime/29.0.3" => "antigravity",
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 trae/1.107.1 claude vscode-wakatime/29.0.3" => "trae",
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 cursornightly/1.105.1 codex vscode-wakatime/29.0.3" => "cursornightly",
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 code-server/1.108.2 codex vscode-wakatime/29.0.3" => "code-server",
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 arduino/1.96.0 codex vscode-wakatime/29.0.3" => "arduino",
      "wakatime/v2.0.12 (darwin-arm64) go1.25.5 antigravity/1.107.0 codex vscode-wakatime/29.0.3 Codex/0.116.0-alpha.1" => "antigravity"
    }

    user_agents.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

      assert_equal editor, result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_keeps_model_before_a_plugin_and_trailing_ai_app
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.21.0 (darwin-25.4.0-arm64) go1.26.4 gpt/5.5-high vscode-wakatime/unknown Codex/26.616.71553-4265 macos-wakatime/5.28.4",
      category: "ai coding"
    )

    assert_equal "vscode", result[:editor]
    assert_equal "gpt/5.5-high", result[:ai_model]
  end

  def test_parse_user_agent_keeps_ai_agent_as_editor_when_a_model_precedes_it
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (linux-x86_64) go1.26.5 gpt/5.6 antigravity-cli/unknown vscode/1.128.0 vscode-wakatime/30.2.1",
      category: "ai coding"
    )

    assert_equal "antigravity-cli", result[:editor]
    assert_equal "gpt/5.6", result[:ai_model]
  end

  def test_parse_user_agent_does_not_treat_a_leading_plugin_as_a_model
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 vscode-wakatime/unknown Codex/26.609.30741 macos-wakatime/5.28.4",
      category: "ai coding"
    )

    assert_equal "vscode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_keeps_a_leading_plugin_before_a_generic_host_plugin
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.21.3 (darwin-27.0.0-arm64) go1.26.4 gpt/5.5-medium vscode-wakatime/unknown /4.5.5-4005005001 macos-wakatime/5.28.3",
      category: "ai coding"
    )

    assert_equal "vscode", result[:editor]
    assert_equal "gpt/5.5-medium", result[:ai_model]
  end

  def test_parse_user_agent_handles_future_model_names_without_an_allowlist
    user_agent = "wakatime/v2.21.4 (linux-6.17.0-x86_64) go1.26.4 mythos/5-high opencode-cli/1.4.4 vscode/1.128.0"

    result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

    assert_equal "opencode-cli", result[:editor]
    assert_equal "mythos/5-high", result[:ai_model]
  end

  def test_parse_user_agent_does_not_treat_a_normal_editor_as_an_ai_model
    user_agent = "wakatime/v2.21.4 (darwin-25.5.0-arm64) go1.26.4 vscode/1.128.0 vscode-wakatime/30.2.1"

    result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

    assert_equal "vscode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_normalizes_selected_wakatime_plugin_to_its_editor
    user_agent = "wakatime/v2.21.4 (linux-x86_64) go1.26.4 gpt/5.5-xhigh vscode-wakatime/unknown vscode/1.124.0"

    result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

    assert_equal "vscode", result[:editor]
    assert_equal "gpt/5.5-xhigh", result[:ai_model]
  end

  def test_parse_user_agent_recognizes_claude_model_before_claude_code_plugin
    user_agent = "wakatime/v2.21.4 (linux-x86_64) go1.26.4 claude/3.5 ClaudeCode/2.1.202 claude-code-wakatime/3.1.6"

    result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

    assert_equal "claude-code", result[:editor]
    assert_equal "claude/3.5", result[:ai_model]
  end

  def test_parse_user_agent_does_not_treat_claude_code_version_as_a_model
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.15.0 (windows-x86_64) go1.26.3 claude/2.1.160 claude-code-wakatime/3.1.5",
      category: "ai coding"
    )

    assert_equal "claude-code", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_uses_the_claude_code_plugin_after_duplicated_client_products
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.1.3 (windows-x86_64) go1.25.5 ClaudeCode/2.1.89 claude/2.1.89 claude-code-wakatime/3.1.5",
      category: "ai coding"
    )

    assert_equal "claude-code", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_recognizes_shared_and_generic_host_plugins
    cases = {
      "wakatime/v2.0.12 (linux-x86_64) go1.25.5 neovim/801 vim-wakatime/11.3.0 ClaudeCode/2.0.31" => [ "neovim", "linux" ],
      "wakatime/v2.13.0 (darwin-x86_64) go1.25.9 Terminal/2.15-470.2 macos-wakatime/5.28.3 waka-relay/0.2.1" => [ "terminal", "macos" ]
    }

    cases.each do |user_agent, (editor, os)|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

      assert_equal editor, result[:editor], user_agent
      assert_equal os, result[:os], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_normalizes_vscode_insiders_before_splitting
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (windows-x86_64) go1.26.5 Visual Studio Code - Insiders/1.108.0-insider (Continue/1.3.38)",
      category: "ai coding"
    )

    assert_equal "vscode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_recognizes_shell_plugin_names
    result = WakatimeUserAgentParser.parse(
      "wakatime/v1.98.3 (linux-x86_64) go1.22.5 wakatime-zsh-plugin/0.2.2"
    )

    assert_equal "zsh", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_prefers_editor_plugin_over_browser_signature
    result = WakatimeUserAgentParser.parse(
      "Mozilla/5.0 (Linux; Android 10) Chrome/125.0 vscode/1.96.0 vscode-wakatime/24.9.2"
    )

    assert_equal "vscode", result[:editor]
    assert_equal "android", result[:os]
  end

  def test_parse_user_agent_handles_legacy_os_editor_pairs
    cases = {
      "Windows/VSCode (Windows/11; Python/3.12.10) CircuPlay" => [ "windows", "vscode" ],
      "Linux/codex-agent" => [ "linux", "codex-agent" ],
      "Darwin/Unity" => [ "macos", "unity" ]
    }

    cases.each do |user_agent, (os, editor)|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal os, result[:os], user_agent
      assert_equal editor, result[:editor], user_agent
    end
  end

  def test_parse_user_agent_recognizes_opera_before_chrome
    result = WakatimeUserAgentParser.parse(
      "Mozilla/5.0 (Windows NT 10.0) Chrome/130.0 Safari/537.36 OPR/115.0.0.0 Chrome/130.0 win_x86-64 chrome-wakatime/4.1.0"
    )

    assert_equal "opera", result[:editor]
    assert_equal "windows", result[:os]
  end

  def test_parse_user_agent_recognizes_android_in_a_wakatime_platform
    result = WakatimeUserAgentParser.parse(
      "wakatime/1.139.1 (Linux-android-5.15.149-android13-unknown) go1.25.5 Unknown/0"
    )

    assert_equal "android", result[:os]
    assert_equal "unknown", result[:editor]
  end

  def test_parse_user_agent_skips_transcript_middleware_before_the_editor
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.0 (linux-x86_64) go1.26.5 glm/5.2-medium exec-wakatime/unknown code-server/1.127.0 vscode-hackatime/30.2.2",
      category: "ai coding"
    )

    assert_equal "code-server", result[:editor]
    assert_equal "glm/5.2-medium", result[:ai_model]
  end

  def test_parse_user_agent_skips_connector_tokens
    result = WakatimeUserAgentParser.parse(
      "wakatime/unset (windows) in vscode/1.125.1 vscode-hackatime/30.2.2001"
    )

    assert_equal "vscode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_recognizes_model_names_that_collide_with_editors
    gemini_model = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (linux-x86_64) go1.26.5 gemini/3.5-flash-high antigravity-ide/1.14.2 antigravityide/1.14.2 vscode-wakatime/30.2.1",
      category: "ai coding"
    )
    codex_model = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 codex/mini-latest codex-cli/0.20.0 terminal/1.0.0",
      category: "ai coding"
    )

    assert_equal "antigravity-ide", gemini_model[:editor]
    assert_equal "gemini/3.5-flash-high", gemini_model[:ai_model]
    assert_equal "codex-cli", codex_model[:editor]
    assert_equal "codex/mini-latest", codex_model[:ai_model]
  end

  def test_parse_user_agent_keeps_colliding_editor_names_when_the_plugin_matches
    codex = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 codex/1.0.0 codex-wakatime/1.3.1",
      category: "ai coding"
    )
    gemini = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.2 (linux-x86_64) go1.26.5 gemini/1.0.0 gemini-wakatime/1.0.0",
      category: "ai coding"
    )

    assert_equal "codex", codex[:editor]
    assert_nil codex[:ai_model]
    assert_equal "gemini", gemini[:editor]
    assert_nil gemini[:ai_model]
  end

  def test_parse_user_agent_handles_official_direct_plugin_families
    cases = {
      "(Windows) vscode/1.90.0 vscode-wakatime/30.2.1" => [ "windows", "vscode" ],
      "unity-wakatime" => [ "", "unity" ],
      "adobexd-wakatime/3.0.0" => [ "", "adobexd" ],
      "Roblox Studio/0.700.0 roblox-studio-wakatime/1.0.0" => [ "", "roblox-studio" ],
      "linux_x86-64 betterdiscord/1.12.0 discord-wakatime/1.0.0" => [ "linux", "betterdiscord" ],
      "Processing processing-wakatime/1.0.0" => [ "", "processing" ]
    }

    cases.each do |user_agent, (os, editor)|
      result = WakatimeUserAgentParser.parse(user_agent)
      assert_equal os, result[:os], user_agent
      assert_equal editor, result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
      assert_nil result[:err], user_agent
    end
  end

  def test_parse_user_agent_handles_direct_ai_transcript_chains
    model = WakatimeUserAgentParser.parse(
      "opus/4-8 claude-code/2.1.202",
      category: "ai coding"
    )
    source = WakatimeUserAgentParser.parse(
      "Codex zsh/5.9 terminal-wakatime/1.0.0",
      category: "ai coding"
    )

    assert_equal "claude-code", model[:editor]
    assert_equal "opus/4-8", model[:ai_model]
    assert_equal "codex", source[:editor]
    assert_nil source[:ai_model]
  end

  def test_parse_user_agent_covers_every_current_ai_parser_user_agent_family
    cases = {
      "claude" => [ "opus/4-8 claude-code/2.1.202", "claude-code", "opus/4-8" ],
      "codex" => [ "gpt/5.4-codex codex-cli/0.142.0", "codex-cli", "gpt/5.4-codex" ],
      "amp" => [ "Amp/0.1.0 vscode/1.90 vscode-wakatime/30.2.1", "amp", nil ],
      "continue" => [ "codestral/25.01 vscode/1.90 vscode-wakatime/30.2.1", "vscode", "codestral/25.01" ],
      "cody" => [ "claude/3.7 vscode/1.90 vscode-wakatime/30.2.1", "vscode", "claude/3.7" ],
      "roo" => [ "vscode/1.90 vscode-wakatime/30.2.1", "vscode", nil ],
      "opencode" => [ "deepseek/3 opencode-cli/1.17.9 vscode/1.90", "opencode-cli", "deepseek/3" ],
      "copilot" => [ "github-copilot/0.55.0 vscode/1.90 vscode-wakatime/30.2.1", "github-copilot", nil ],
      "cursor" => [ "claude/4 Cursor/1.125.0 vscode-wakatime/30.2.1", "cursor", "claude/4" ],
      "windsurf" => [ "swe/1 windsurf/1.107.0 vscode-wakatime/30.2.1", "windsurf", "swe/1" ],
      "qoder" => [ "qoder/1.13.0 vscode-wakatime/30.2.1", "qoder", nil ],
      "kiro" => [ "kiro/1.107.1 vscode-wakatime/30.2.1", "kiro", nil ],
      "cline" => [ "vscode/1.90 vscode-wakatime/30.2.1", "vscode", nil ],
      "gemini" => [ "gemini/3.1-pro-high vscode/1.90 vscode-wakatime/30.2.1", "vscode", "gemini/3.1-pro-high" ],
      "qwen" => [ "qwen/3 qwen-code-cli/0.17.0 zed/1.11.3", "qwen-code-cli", "qwen/3" ],
      "pi" => [ "gpt/5.6 zsh/5.9 terminal-wakatime/1.1.5", "zsh", "gpt/5.6" ],
      "goose" => [ "llama/4 neovim/0.12 wakatime.nvim/12.0.0", "neovim", "llama/4" ]
    }

    cases.each do |parser, (product_chain, editor, ai_model)|
      result = WakatimeUserAgentParser.parse(
        "wakatime/v2.22.2 (linux-x86_64) go1.26.5 #{product_chain}",
        category: "ai coding"
      )

      assert_equal editor, result[:editor], parser
      if ai_model
        assert_equal ai_model, result[:ai_model], parser
      else
        assert_nil result[:ai_model], parser
      end
    end
  end

  def test_parse_user_agent_preserves_a_standalone_cli_product
    result = WakatimeUserAgentParser.parse("wakatime-cli/1.2.3")

    assert_equal "wakatime-cli", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_skips_parenthesized_metadata_before_the_ai_model
    result = WakatimeUserAgentParser.parse(
      "wakatime/1.0 (linux) (extra) opus/4-8 claude-code/2.1",
      category: "ai coding"
    )

    assert_equal "linux", result[:os]
    assert_equal "claude-code", result[:editor]
    assert_equal "opus/4-8", result[:ai_model]
    assert_nil result[:err]
  end

  def test_parse_user_agent_with_Firefox
    user_agent = "Firefox/139.0 linux_x86-64 firefox-wakatime/4.1.0"
    result = WakatimeUserAgentParser.parse(user_agent)
    assert_equal "linux", result[:os]
    assert_equal "firefox", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_uses_plugin_fallback_and_skips_middleware
    emacs = WakatimeUserAgentParser.parse(
      "wakatime/13.0.4 (Linux-5.4.64-x86_64-with-glibc2.2.5) Python3.7.6.final.0 emacs-wakatime/1.0.2"
    )
    helix = WakatimeUserAgentParser.parse(
      "wakatime/1.139.1 (linux-6.18.8-unknown) go1.25.5 helix/25.07.1 (74075bb5) wakatime-ls/0.2.2 helix-wakatime/0.2.2"
    )

    assert_equal "linux", emacs[:os]
    assert_equal "emacs", emacs[:editor]
    assert_equal "helix", helix[:editor]
  end

  def test_parse_user_agent_handles_wsl_and_browser_extension_user_agents
    wsl = WakatimeUserAgentParser.parse(
      "wakatime/v1.106.1 (linux-5.15.167.4-microsoft-standard-WSL2-unknown) go1.23.3 cursor/1.93.1 vscode-wakatime/24.9.2"
    )
    edge = WakatimeUserAgentParser.parse(
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 Edg/116.0.1938.62 win_x86-64 edge-wakatime/3.0.18"
    )

    assert_equal "wsl", wsl[:os]
    assert_equal "cursor", wsl[:editor]
    assert_equal "windows", edge[:os]
    assert_equal "edge", edge[:editor]
  end

  def test_parse_user_agent_does_not_require_a_known_editor_for_two_product_chain
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.21.4 (linux-x86_64) go1.26.4 future-editor/1.0.0 vscode-wakatime/30.2.1",
      category: "ai coding"
    )

    assert_equal "future-editor", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_recognizes_standalone_claude_code_versions
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.15.3 (darwin-25.5.0-arm64) go1.26.4 Claude/2.1.89",
      category: "ai coding"
    )

    assert_equal "claude-code", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_skips_node_and_java_runtimes
    cases = {
      "wakatime/1.115.1 (linux-x64) node/26.2.0 wakatime/v2.14.5 (linux-x86_64) go1.26.3 neovim/0.12 wakatime.nvim/12.0.0" => "neovim",
      "wakatime/v1.102.0 (Windows-11-10.0.22631-SP0) Java21.0.2 IntelliJ/2024.3.1 IntelliJ-wakatime/15.1.0" => "intellij"
    }

    cases.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal editor, result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_keeps_a_slash_versioned_python_editor_product
    result = WakatimeUserAgentParser.parse(
      "wakatime/v1.130.1 (windows-10.0.19045.6093-x86_64) go1.24.4 Python/unknown windows-wakatime/2.1.7"
    )

    assert_equal "python", result[:editor]
    assert_equal "windows", result[:os]
  end

  def test_parse_user_agent_skips_a_numeric_slash_versioned_python_runtime
    result = WakatimeUserAgentParser.parse(
      "wakatime/0.1.0 (Windows-11-AMD64) Python/3.12.10 VS Code/0.1.0"
    )

    assert_equal "vscode", result[:editor]
    assert_equal "windows", result[:os]
  end

  def test_parse_user_agent_recognizes_legacy_pycharm_plugin_formats
    user_agents = [
      "wakatime/v1.53.3 (windows-10.0.19041.1415-unknown) go1.18.3 Python/2022.2 Python-wakatime/14.0.6",
      "wakatime/v1.62.1 (linux-5.15.85-1-MANJARO-unknown) go1.19.5 Python/2023.1 EAP Python-wakatime/14.1.3",
      "wakatime/v1.60.4 (linux-5.15.78-1-MANJARO-unknown) go1.19.4 Python/2022.3.1 RC Python-wakatime/14.1.3"
    ]

    user_agents.each do |user_agent|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal "pycharm", result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_skips_easyeda_web_transport_marker
    result = WakatimeUserAgentParser.parse(
      "wakatime/0.1.7 (web) web EasyEDAPro/2.2.34.6 easyeda-wakatime/0.1.7"
    )

    assert_equal "easyedapro", result[:editor]
    assert_equal "", result[:os]
  end

  def test_parse_user_agent_recovers_legacy_editors_from_the_platform
    user_agents = {
      "wakatime/1.0.0 (VSCode/1.85.0)" => "vscode",
      "wakatime/v1.102.1 (VSCode, Custom)" => "vscode",
      "wakatime/v1.102.1 (VS Code)" => "vscode",
      "wakatime/v1.102.1 (Termux-wakatime)" => "termux",
      "wakatime/v1.102.1 (WebStorm)" => "webstorm"
    }

    user_agents.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal editor, result[:editor], user_agent
      assert_equal "", result[:os], user_agent
    end
  end

  def test_parse_user_agent_does_not_treat_opencode_desktop_as_a_model
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.21.2 (windows-10.0.26200.8737-x86_64) go1.26.4 opencode-desktop/local opencode-wakatime/unknown",
      category: "ai coding"
    )

    assert_equal "opencode-desktop", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_recognizes_legacy_product_aliases
    user_agents = {
      "wakatime/1.0.0 (Linux) x antigravity" => "antigravity",
      "wakatime/v1.115.3 (linux-x86_64) go1.24.2 ik11235/wakatime.fish/0.0.6" => "fish",
      "wakatime/v1.131.0 (darwin-arm64) go1.24.4 hackatime-zed-unknown" => "zed",
      "wakatime/1.60.4 (linux-x86_64) go1.22.0 kdevelop-wakatime-plugin1.0.0" => "kdevelop",
      "wakatime/v1.139.4 (darwin-arm64) go1.25.5 ZedPreview/0.230.0 macos-wakatime/5.28.3" => "zed",
      "wakatime/unset (Blender-4.3.2) cyteon/blender-hackatime" => "blender"
    }

    user_agents.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal editor, result[:editor], user_agent
    end
  end

  def test_parse_user_agent_recovers_editors_from_malformed_legacy_formats
    user_agents = {
      "wakatime/v1.115.3 (windows-x86_64) go1.24.2 \\\"vscode/1.101.0 vscode-wakatime/25.0.4\\" => "vscode",
      "Mozilla/5.0 (Windows NT; Windows NT 10.0; en-US) WindowsPowerShell/5.1.26100.2161" => "windowspowershell",
      "(Darwin) Darwin/1.0.0 unitime-wakatime/0.1.0" => "unitime",
      "1.0/codex-agent" => "codex-agent"
    }

    user_agents.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal editor, result[:editor], user_agent
    end
  end

  def test_parse_user_agent_accepts_one_meaningful_bare_editor
    user_agents = {
      "Vscode" => [ "vscode", "" ],
      "CustomClient" => [ "customclient", "" ],
      "SYNTHETIC-Audio" => [ "synthetic-audio", "" ],
      "Windows vscode" => [ "vscode", "windows" ],
      "codex-agent (linux)" => [ "codex-agent", "linux" ],
      "Visual Studio Code" => [ "vscode", "" ],
      "wakatime/VSCode" => [ "vscode", "" ]
    }

    user_agents.each do |user_agent, (editor, os)|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal editor, result[:editor], user_agent
      assert_equal os, result[:os], user_agent
      assert_nil result[:err], user_agent
    end
  end

  def test_parse_user_agent_normalizes_platform_os_aliases
    user_agents = {
      "wakatime/unset (Chrome OS) in vscode/1.126.0 vscode-hackatime/30.2.2001" => "chromeos",
      "wakatime/v1.102.1 (Win11-wakatime) vscode/1.94.2 vscode-wakatime/24.6.2" => "windows",
      "wakatime/v1.0.0 (Win32) MORP Editor/1.0.0 morp-profile-editor/1.0.0" => "windows",
      "wakatime/6.2.0 (Darwin; arm64; macOS 15.2) PyCharm/2024.3.1 PyCharm-wakatime/15.0.3" => "macos",
      "wakatime/1.107.0 (Macintosh; arm64; macOS 15.2) VSCode/1.86 vscode-wakatime/24.0.0" => "macos",
      "wakatime/unset (iPhone) in vscode/1.128.0 vscode-hackatime/30.2.2001" => "ios",
      "wakatime/unset (iPad) in vscode/1.128.0 vscode-hackatime/30.2.2001" => "ios"
    }

    user_agents.each do |user_agent, os|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal os, result[:os], user_agent
    end
  end

  def test_parse_user_agent_does_not_invent_operating_systems_from_client_labels
    user_agents = [
      "wakatime/6.2.0 (C# Client)",
      "wakatime/6.2.0 (Python Client)",
      "wakatime/0.1.7 (web) web EasyEDAPro/2.2.34.6 easyeda-wakatime/0.1.7",
      "wakatime/unset (none-Chrome-none) figma-wakatime/1.2.5",
      "wakatime/unset (Blender-4.3.2) cyteon/blender-hackatime",
      "wakatime/v1.102.1 (OS_NAME)",
      "wakatime/v1.102.1 (WebStorm)"
    ]

    user_agents.each do |user_agent|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal "", result[:os], user_agent
    end
  end

  def test_parse_user_agent_extracts_models_embedded_in_agent_versions
    copilot = WakatimeUserAgentParser.parse(
      "wakatime/v2.16.1 (windows-x86_64) go1.26.4 Copilot/claude-haiku-4.5 vscode/1.124.2 vscode-wakatime/30.2.1",
      category: "ai coding"
    )
    gemini = WakatimeUserAgentParser.parse(
      "wakatime/v2.14.10 (windows-x86_64) go1.26.3 Gemini/gemini-3-flash-preview pycharm/2025.2.4 pycharm-wakatime/15.0.4",
      category: "ai coding"
    )

    assert_equal "copilot", copilot[:editor]
    assert_equal "claude-haiku-4.5", copilot[:ai_model]
    assert_equal "gemini", gemini[:editor]
    assert_equal "gemini-3-flash-preview", gemini[:ai_model]
  end

  def test_parse_user_agent_does_not_treat_agent_semvers_as_embedded_models
    user_agents = [
      "wakatime/v2.13.1 (windows-x86_64) go1.26.3 Copilot/0.35.2 vscode/1.119.0 vscode-wakatime/30.1.3",
      "wakatime/v2.7.0 (windows-x86_64) go1.25.9 Copilot/0.44.2Cursor/unknown windows-wakatime/3.0.0",
      "wakatime/v2.14.10 (darwin-arm64) go1.26.3 Gemini/1.80.15.516-1.80.15.516"
    ]

    user_agents.each do |user_agent|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_recovers_a_product_before_a_legacy_platform_comment
    result = WakatimeUserAgentParser.parse(
      "Custom_editor (Linux/6.1.0-37-amd64; Python/3.11.2) HSSIoT"
    )

    assert_equal "custom_editor", result[:editor]
    assert_equal "linux", result[:os]
    assert_nil result[:err]
  end

  def test_parse_user_agent_recognizes_standalone_model_only_formats
    user_agents = {
      "wakatime/v2.21.4 (linux-x86_64) go1.26.4 glm/1.0" => "glm/1.0",
      "wakatime/v2.21.4 (linux-x86_64) go1.26.4 nemotron/1.0" => "nemotron/1.0",
      "wakatime/v2.21.4 (windows-x86_64) go1.26.4 composer/2.5" => "composer/2.5"
    }

    user_agents.each do |user_agent, model|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

      assert_equal "", result[:editor], user_agent
      assert_equal model, result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_uses_a_specific_ai_plugin_after_the_model
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.21.2 (darwin-arm64) go1.26.4 deepseek/4-flash-free oh-my-pi-wakatime/1",
      category: "ai coding"
    )

    assert_equal "pi", result[:editor]
    assert_equal "deepseek/4-flash-free", result[:ai_model]
  end

  def test_parse_user_agent_recognizes_hubai_nitro_as_one_editor
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.15.0 (darwin-arm64) go1.26.3 HubAI Nitro/1.1.5-beta.36",
      category: "ai coding"
    )

    assert_equal "hubai-nitro", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_skips_mcp_wakatime_middleware
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.21.2 (darwin-25.5.0-arm64) go1.26.4 gpt/5.5-high mcp-wakatime/unknown vscode/1.126.0 vscode-wakatime/30.2.1",
      category: "ai coding"
    )

    assert_equal "vscode", result[:editor]
    assert_equal "gpt/5.5-high", result[:ai_model]
  end

  def test_parse_user_agent_normalizes_multiword_editor_products_in_all_categories
    cases = {
      "wakatime/v1.0 (Linux) VS Code/1.90" => "vscode",
      "wakatime/v1.0 (Linux) VisualStudioCode/1.90" => "vscode",
      "wakatime/v1.0 (Linux) Code - OSS/1.90" => "code-oss",
      "wakatime/v1.0 (Linux) Codex Desktop/1.0.0 codex-wakatime/1.2.0" => "codex-desktop"
    }

    cases.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal editor, result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_normalizes_versioned_and_legacy_application_names
    cases = {
      "wakatime/v1.53.4 (windows-x86_64) go1.18.4 Idea/2022.1.3 Idea-wakatime/14.1.0" => "intellijidea",
      "wakatime/v1.130.1 (windows-x86_64) go1.24.4 IntelliJIDEAUltimateEdition/unknown windows-wakatime/2.1.7" =>
        "intellijidea",
      "wakatime/v1.139.1 (windows-x86_64) go1.25.5 GodotEngine/unknown windows-wakatime/3.0.0" => "godot",
      "wakatime/v1.132.1 (windows-x86_64) go1.25.5 KiCadEDA9.0.6/unknown windows-wakatime/2.1.7" => "kicad",
      "wakatime/v1.115.1 (darwin-arm64) go1.24.2 RobloxStudio/0.653.0 macos-wakatime/5.26.3" =>
        "roblox-studio"
    }

    cases.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal editor, result[:editor], user_agent
    end
  end

  def test_parse_user_agent_skips_vscode_tracker_wrapper
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.15.0 (darwin-25.1.0-arm64) vscode-hackatime-tracker/1.2.0 VS Code/1.96.0"
    )

    assert_equal "vscode", result[:editor]
    assert_equal "macos", result[:os]
  end

  def test_parse_user_agent_uses_continue_host_editor_without_inventing_a_model_fragment
    cases = {
      "Continue/Gemini 3.1 Pro Visual Studio Code/1.124.2 (Continue/1.2.22)" => "vscode",
      "Continue/Claude Sonnet 4.6 VSCodium/1.124.2 (Continue/1.2.22)" => "vscodium",
      "Continue/Claude 4 Sonnet IntelliJ IDEA 2025.2.2/2025.2.2 (Continue/1.0.44)" => "intellijidea",
      "Continue/Llama 3.1 8B Code - OSS/1.107.1 (Continue/1.2.14)" => "code-oss"
    }

    cases.each do |product_chain, editor|
      result = WakatimeUserAgentParser.parse(
        "wakatime/v2.16.1 (linux-x86_64) go1.26.4 #{product_chain}",
        category: "ai coding"
      )

      assert_equal editor, result[:editor], product_chain
      assert_nil result[:ai_model], product_chain
    end
  end

  def test_parse_user_agent_recognizes_browser_os_variants_without_substring_false_positives
    cases = {
      "Chrome/145.0.0.0 macOS/10.15.7 onshape-wakatime/2.1.0" => [ "macos", "onshape" ],
      "Chrome/147.0.0.0 cros_x86-64 chrome-wakatime/4.1.0" => [ "chromeos", "chrome" ],
      "onshape-wakatime-plugin_Microsoft Edge/144.0.0.0 macOS_10.15.7 onshape-wakatime/1.0.1" => [ "macos", "onshape" ],
      "(Chrome OS) vscode/1.102.0-insider vscode-wakatime/25.0.6" => [ "chromeos", "vscode" ],
      "(Android) vscode/1.102.0 vscode-wakatime/25.0.6" => [ "android", "vscode" ]
    }

    cases.each do |user_agent, (os, editor)|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal os, result[:os], user_agent
      assert_equal editor, result[:editor], user_agent
    end
  end

  def test_parse_user_agent_recognizes_edge_android_signature
    result = WakatimeUserAgentParser.parse(
      "Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/145.0 Mobile Safari/537.36 EdgA/145.0 edge-wakatime/4.0.0"
    )

    assert_equal "edge", result[:editor]
    assert_equal "android", result[:os]
  end

  def test_parse_user_agent_normalizes_legacy_onshape_browser_prefixes
    cases = {
      "onshape-wakatime-plugin_Chrome/138.0.0.0 Windows_NT_10.0 onshape-wakatime/1.0.1" => "windows",
      "onshape-wakatime-plugin_Firefox/144.0 macOS_10.15 onshape-wakatime/1.0.1" => "macos",
      "onshape-wakatime-plugin_Firefox/146.0 Linux_undefined onshape-wakatime/1.0.1" => "linux",
      "onshape-wakatime-plugin_Opera/121.0.0.0 Windows_NT_10.0 onshape-wakatime/1.0.1" => "windows"
    }

    cases.each do |user_agent, os|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal "onshape", result[:editor], user_agent
      assert_equal os, result[:os], user_agent
    end
  end

  def test_parse_user_agent_skips_version_and_punctuation_prefixes
    cases = {
      "wakatime/v1.106.0 (windows-x86_64) go1.23.3 1.23.3 kicad/8.99.0 kicad-wakatime/0.0.0" => "kicad",
      "wakatime/1.0 (Linux) - SlideTap/unknown" => "slidetap",
      "wakatime/v1.132.1 (windows-x86_64) go1.25.5 Python + Streamlit/unknown Python + Streamlit-wakatime/0.0.0" => "streamlit"
    }

    cases.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent)

      assert_equal editor, result[:editor], user_agent
    end
  end

  def test_parse_user_agent_recognizes_a_model_before_only_a_fallback_plugin
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.0 (darwin-24.6.0-arm64) go1.26.5 gpt/5.5-high vscode-wakatime/unknown",
      category: "ai coding"
    )

    assert_equal "vscode", result[:editor]
    assert_equal "gpt/5.5-high", result[:ai_model]
  end

  def test_parse_user_agent_recognizes_a_model_before_a_generic_host_plugin
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.21.3 (darwin-27.0.0-arm64) go1.26.4 gpt/5.4-medium /4.5.5-4005005001 macos-wakatime/5.28.3",
      category: "ai coding"
    )

    assert_equal "", result[:editor]
    assert_equal "gpt/5.4-medium", result[:ai_model]
  end

  def test_parse_user_agent_recognizes_a_bare_continue_prefix_before_the_host
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.19.0 (linux-x86_64) go1.26.4 NeuralNexusLab/CodeXor:3b Continue Code - OSS/1.118.1 (Continue/1.2.24)",
      category: "ai coding"
    )

    assert_equal "code-oss", result[:editor]
    assert_equal "NeuralNexusLab/CodeXor:3b", result[:ai_model]
  end

  def test_parse_user_agent_does_not_treat_known_clients_as_models
    cases = {
      "wakatime/v2.0.12 (linux-x86_64) go1.25.5 t3code_desktop/1.0.0 codex-wakatime/1.2.0 Codex/0.116.0" => "t3code_desktop",
      "wakatime/v2.14.7 (windows-x86_64) go1.26.3 codex/0.133.0 hackatime-fix/1.0" => "codex",
      "wakatime/v2.0.12 (linux-wsl2-x86_64) go1.25.5 fish/4.5.0 terminal-wakatime/v1.1.5 ClaudeCode/2.1.89" => "fish"
    }

    cases.each do |user_agent, editor|
      result = WakatimeUserAgentParser.parse(user_agent, category: "ai coding")

      assert_equal editor, result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
    end
  end

  def test_parse_user_agent_prefers_a_specific_later_editor_plugin_over_a_fallback_plugin
    result = WakatimeUserAgentParser.parse(
      "wakatime/v2.22.0 (windows-x86_64) go1.26.5 gpt/5.5-high vscode-wakatime/unknown godot/4.5.0 godot-wakatime/1.0.0",
      category: "ai coding"
    )

    assert_equal "godot", result[:editor]
    assert_equal "gpt/5.5-high", result[:ai_model]
  end

  def test_parse_user_agent_with_invalid_user_agent
    user_agent = "invalid-user-agent"
    result = WakatimeUserAgentParser.parse(user_agent)
    assert_equal "", result[:os]
    assert_equal "", result[:editor]
    assert_equal "failed to parse user agent string", result[:err]
  end

  def test_parse_user_agent_preserves_detected_os_when_the_editor_is_unparseable
    result = WakatimeUserAgentParser.parse("Windows")

    assert_equal "windows", result[:os]
    assert_equal "", result[:editor]
    assert_equal "failed to parse user agent string", result[:err]
  end

  def test_parse_user_agent_rejects_an_unstructured_spaced_product
    result = WakatimeUserAgentParser.parse("codex agent/1.0")

    assert_equal "", result[:editor]
    assert_equal "failed to parse user agent string", result[:err]
  end
end
