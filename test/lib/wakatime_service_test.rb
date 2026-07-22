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
    assert_equal "macos", result[:os]
    assert_equal "vscode", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_without_a_runtime_token
    result = WakatimeService.parse_user_agent(
      "wakatime/1.0 (linux-x86_64) vscode/1.90"
    )

    assert_equal "linux", result[:os]
    assert_equal "vscode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_without_products_after_the_platform
    result = WakatimeService.parse_user_agent(
      "wakatime/v1.86.0 (windows-10.0.22631-x86_64)"
    )

    assert_equal "windows", result[:os]
    assert_equal "", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_with_GitHub_Desktop
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 github-desktop/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "macos", result[:os]
    assert_equal "github-desktop", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_Figma
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 figma/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "macos", result[:os]
    assert_equal "figma", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_Terminal
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 terminal/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "macos", result[:os]
    assert_equal "terminal", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_with_vim
    user_agent = "wakatime/v1.0.0 (darwin-arm64) go1.0.0 vim/1.0.0"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "macos", result[:os]
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
    assert_equal "macos", result[:os]
    assert_equal "cursor", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_separates_ai_model_from_claude_code_editor
    user_agent = "wakatime/v2.21.4 (darwin-25.5.0-arm64) go1.26.4 opus/4-8 claude-code/2.1.202"

    result = WakatimeService.parse_user_agent(user_agent, category: "ai coding")

    assert_equal "macos", result[:os]
    assert_equal "claude-code", result[:editor]
    assert_equal "opus/4-8", result[:ai_model]
  end

  def test_parse_user_agent_separates_ai_model_from_copilot_cli_editor
    user_agent = "wakatime/v2.21.4 (windows-10.0.19045.5011-x86_64) go1.26.4 gpt/5.3-codex github-copilot-cli/1.0.68 copilot/1.0.68 cursor/1.105.1 vscode-wakatime/30.2.1"

    result = WakatimeService.parse_user_agent(user_agent, category: "ai coding")

    assert_equal "windows", result[:os]
    assert_equal "copilot-cli", result[:editor]
    assert_equal "gpt/5.3-codex", result[:ai_model]
  end

  def test_parse_user_agent_uses_the_first_ai_editor_after_the_model
    vscode = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 gpt/5.6 vscode-wakatime/unknown Zed/1.11.3 Zed-hackatime/0.3.1",
      category: "ai coding"
    )
    opencode = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 fable/5 opencode-cli/local Zed/1.11.3 Zed-hackatime/0.3.1",
      category: "ai coding"
    )

    assert_equal "vscode", vscode[:editor]
    assert_equal "gpt/5.6", vscode[:ai_model]
    assert_equal "opencode-cli", opencode[:editor]
    assert_equal "fable/5", opencode[:ai_model]
  end

  def test_parse_user_agent_skips_ai_agent_prefix_without_a_model
    opencode = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 opencode-cli/local Zed/1.11.3 Zed-hackatime/0.3.1",
      category: "ai coding"
    )
    amp = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 amp/unknown Zed/1.11.3 Zed-hackatime/0.3.1",
      category: "ai coding"
    )

    assert_equal "zed", opencode[:editor]
    assert_nil opencode[:ai_model]
    assert_equal "zed", amp[:editor]
    assert_nil amp[:ai_model]
  end

  def test_parse_user_agent_recognizes_dot_named_wakatime_plugins
    result = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (linux-x86_64) go1.26.5 neovim/0.12 wakatime.nvim/12.0.0",
      category: "ai coding"
    )

    assert_equal "neovim", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_ignores_parenthesized_plugin_metadata
    result = WakatimeService.parse_user_agent(
      "wakatime/v2.21.4 (linux-x86_64) go1.26.4 VSCodium/1.121.0 (Continue/2.0.0)",
      category: "ai coding"
    )

    assert_equal "vscodium", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_does_not_treat_ai_agent_products_as_models
    user_agents = {
      "wakatime/v2.22.0 (windows-x86_64) go1.26.5 antigravity-desktop/unknown vscode/1.128.0 vscode-wakatime/30.2.1" => "vscode",
      "wakatime/v2.21.4 (linux-x86_64) go1.26.4 github-copilot/0.55.0 VSCodium/1.121.0 vscode-wakatime/30.2.1" => "vscodium",
      "wakatime/v2.14.7 (darwin-arm64) go1.26.3 ClaudeCode/2.1.197 cursor/1.105.1 vscode-wakatime/30.2.1" => "cursor",
      "wakatime/v2.22.2 (linux-x86_64) go1.26.5 qwen-code-cli/0.17.0 zed/1.11.3 zed-hackatime/0.3.1" => "zed",
      "wakatime/v2.16.1 (linux-x86_64) go1.26.4 OpenCode/1.17.9 opencode-cli/1.17.9 opencode-wakatime/1.3.8" => "opencode"
    }

    user_agents.each do |user_agent, editor|
      result = WakatimeService.parse_user_agent(user_agent, category: "ai coding")
      assert_equal editor, result[:editor]
      assert_nil result[:ai_model]
    end
  end

  def test_parse_user_agent_keeps_ai_agent_as_editor_when_a_model_precedes_it
    result = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (linux-x86_64) go1.26.5 gpt/5.6 antigravity-cli/unknown vscode/1.128.0 vscode-wakatime/30.2.1",
      category: "ai coding"
    )

    assert_equal "antigravity-cli", result[:editor]
    assert_equal "gpt/5.6", result[:ai_model]
  end

  def test_parse_user_agent_does_not_treat_a_leading_plugin_as_a_model
    result = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 vscode-wakatime/unknown Codex/26.609.30741 macos-wakatime/5.28.4",
      category: "ai coding"
    )

    assert_equal "vscode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_handles_future_model_names_without_an_allowlist
    user_agent = "wakatime/v2.21.4 (linux-6.17.0-x86_64) go1.26.4 mythos/5-high opencode-cli/1.4.4 vscode/1.128.0"

    result = WakatimeService.parse_user_agent(user_agent, category: "ai coding")

    assert_equal "opencode-cli", result[:editor]
    assert_equal "mythos/5-high", result[:ai_model]
  end

  def test_parse_user_agent_does_not_treat_a_normal_editor_as_an_ai_model
    user_agent = "wakatime/v2.21.4 (darwin-25.5.0-arm64) go1.26.4 vscode/1.128.0 vscode-wakatime/30.2.1"

    result = WakatimeService.parse_user_agent(user_agent, category: "ai coding")

    assert_equal "vscode", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_normalizes_selected_wakatime_plugin_to_its_editor
    user_agent = "wakatime/v2.21.4 (linux-x86_64) go1.26.4 gpt/5.5-xhigh vscode-wakatime/unknown vscode/1.124.0"

    result = WakatimeService.parse_user_agent(user_agent, category: "ai coding")

    assert_equal "vscode", result[:editor]
    assert_equal "gpt/5.5-xhigh", result[:ai_model]
  end

  def test_parse_user_agent_recognizes_claude_model_before_claude_code_plugin
    user_agent = "wakatime/v2.21.4 (linux-x86_64) go1.26.4 claude/3.5 claude-code-wakatime/3.1.6"

    result = WakatimeService.parse_user_agent(user_agent, category: "ai coding")

    assert_equal "claude-code", result[:editor]
    assert_equal "claude/3.5", result[:ai_model]
  end

  def test_parse_user_agent_recognizes_model_names_that_collide_with_editors
    gemini_model = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (linux-x86_64) go1.26.5 gemini/3.5-flash-high antigravity-ide/1.14.2 antigravityide/1.14.2 vscode-wakatime/30.2.1",
      category: "ai coding"
    )
    codex_model = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 codex/mini-latest codex-cli/0.20.0 terminal/1.0.0",
      category: "ai coding"
    )

    assert_equal "antigravity-ide", gemini_model[:editor]
    assert_equal "gemini/3.5-flash-high", gemini_model[:ai_model]
    assert_equal "codex-cli", codex_model[:editor]
    assert_equal "codex/mini-latest", codex_model[:ai_model]
  end

  def test_parse_user_agent_keeps_colliding_editor_names_when_the_plugin_matches
    codex = WakatimeService.parse_user_agent(
      "wakatime/v2.22.2 (darwin-arm64) go1.26.5 codex/1.0.0 codex-wakatime/1.3.1",
      category: "ai coding"
    )
    gemini = WakatimeService.parse_user_agent(
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
      result = WakatimeService.parse_user_agent(user_agent)
      assert_equal os, result[:os], user_agent
      assert_equal editor, result[:editor], user_agent
      assert_nil result[:ai_model], user_agent
      assert_nil result[:err], user_agent
    end
  end

  def test_parse_user_agent_handles_direct_ai_transcript_chains
    model = WakatimeService.parse_user_agent(
      "opus/4-8 claude-code/2.1.202",
      category: "ai coding"
    )
    source = WakatimeService.parse_user_agent(
      "Codex zsh/5.9 terminal-wakatime/1.0.0",
      category: "ai coding"
    )

    assert_equal "claude-code", model[:editor]
    assert_equal "opus/4-8", model[:ai_model]
    assert_equal "zsh", source[:editor]
    assert_nil source[:ai_model]
  end

  def test_parse_user_agent_covers_every_current_ai_parser_user_agent_family
    cases = {
      "claude" => [ "opus/4-8 claude-code/2.1.202", "claude-code", "opus/4-8" ],
      "codex" => [ "gpt/5.4-codex codex-cli/0.142.0", "codex-cli", "gpt/5.4-codex" ],
      "amp" => [ "Amp/0.1.0 vscode/1.90 vscode-wakatime/30.2.1", "vscode", nil ],
      "continue" => [ "codestral/25.01 vscode/1.90 vscode-wakatime/30.2.1", "vscode", "codestral/25.01" ],
      "cody" => [ "claude/3.7 vscode/1.90 vscode-wakatime/30.2.1", "vscode", "claude/3.7" ],
      "roo" => [ "vscode/1.90 vscode-wakatime/30.2.1", "vscode", nil ],
      "opencode" => [ "deepseek/3 opencode-cli/1.17.9 vscode/1.90", "opencode-cli", "deepseek/3" ],
      "copilot" => [ "github-copilot/0.55.0 vscode/1.90 vscode-wakatime/30.2.1", "vscode", nil ],
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
      result = WakatimeService.parse_user_agent(
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
    result = WakatimeService.parse_user_agent("wakatime-cli/1.2.3")

    assert_equal "wakatime-cli", result[:editor]
    assert_nil result[:err]
  end

  def test_parse_user_agent_skips_parenthesized_metadata_before_the_ai_model
    result = WakatimeService.parse_user_agent(
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
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "linux", result[:os]
    assert_equal "firefox", result[:editor]
    assert_nil result[:error]
  end

  def test_parse_user_agent_uses_plugin_fallback_and_skips_middleware
    emacs = WakatimeService.parse_user_agent(
      "wakatime/13.0.4 (Linux-5.4.64-x86_64-with-glibc2.2.5) Python3.7.6.final.0 emacs-wakatime/1.0.2"
    )
    helix = WakatimeService.parse_user_agent(
      "wakatime/1.139.1 (linux-6.18.8-unknown) go1.25.5 helix/25.07.1 (74075bb5) wakatime-ls/0.2.2 helix-wakatime/0.2.2"
    )

    assert_equal "linux", emacs[:os]
    assert_equal "emacs", emacs[:editor]
    assert_equal "helix", helix[:editor]
  end

  def test_parse_user_agent_handles_wsl_and_browser_extension_user_agents
    wsl = WakatimeService.parse_user_agent(
      "wakatime/v1.106.1 (linux-5.15.167.4-microsoft-standard-WSL2-unknown) go1.23.3 cursor/1.93.1 vscode-wakatime/24.9.2"
    )
    edge = WakatimeService.parse_user_agent(
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 Edg/116.0.1938.62 win_x86-64 edge-wakatime/3.0.18"
    )

    assert_equal "wsl", wsl[:os]
    assert_equal "cursor", wsl[:editor]
    assert_equal "windows", edge[:os]
    assert_equal "edge", edge[:editor]
  end

  def test_parse_user_agent_does_not_require_a_known_editor_for_two_product_chain
    result = WakatimeService.parse_user_agent(
      "wakatime/v2.21.4 (linux-x86_64) go1.26.4 future-editor/1.0.0 vscode-wakatime/30.2.1",
      category: "ai coding"
    )

    assert_equal "future-editor", result[:editor]
    assert_nil result[:ai_model]
  end

  def test_parse_user_agent_with_invalid_user_agent
    user_agent = "invalid-user-agent"
    result = WakatimeService.parse_user_agent(user_agent)
    assert_equal "", result[:os]
    assert_equal "", result[:editor]
    assert_equal "failed to parse user agent string", result[:err]
  end

  def test_parse_user_agent_rejects_an_unstructured_spaced_product
    result = WakatimeService.parse_user_agent("codex agent/1.0")

    assert_equal "", result[:editor]
    assert_equal "failed to parse user agent string", result[:err]
  end
end
