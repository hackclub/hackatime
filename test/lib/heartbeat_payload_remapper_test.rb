require "test_helper"

class HeartbeatPayloadRemapperTest < Minitest::Test
  def test_remaps_fields_swapped_by_affected_macos_wakatime_versions
    attributes = {
      entity: "hackatime",
      project: "heartbeat_ingest.rb",
      type: "app",
      user_agent: "wakatime/v1.100.1 (darwin-arm64) Zed/0.198.5 macos-wakatime/5.28.4-alpha.1"
    }

    remapped = HeartbeatPayloadRemapper.remap_fields(attributes)
    remapped = HeartbeatPayloadRemapper.remap_language(remapped)

    assert_equal "heartbeat_ingest.rb", remapped[:entity]
    assert_equal "hackatime", remapped[:project]
    assert_equal "Ruby", remapped[:language]
    assert_equal "hackatime", attributes[:entity]
  end

  def test_preserves_fields_from_unaffected_macos_wakatime_versions
    old_zed = {
      entity: "heartbeat_ingest.rb",
      project: "hackatime",
      type: "app",
      user_agent: "wakatime/v1.100.1 (darwin-arm64) Zed/0.161.2 macos-wakatime/5.28.4-alpha.1"
    }
    fixed_client = old_zed.merge(
      user_agent: "wakatime/v1.100.1 (darwin-arm64) Zed/0.198.5 macos-wakatime/5.28.5-alpha.1"
    )

    assert_equal [ "heartbeat_ingest.rb", "hackatime" ],
      HeartbeatPayloadRemapper.remap_fields(old_zed).values_at(:entity, :project)
    assert_equal [ "heartbeat_ingest.rb", "hackatime" ],
      HeartbeatPayloadRemapper.remap_fields(fixed_client).values_at(:entity, :project)
  end

  def test_authoritative_extension_overrides_client_reported_language
    assert_equal "Luau", remap_language("Lua", "/a/main.luau")
    assert_equal "Luau", remap_language("PLAIN_TEXT", "/a/main.luau")
    assert_equal "Luau", remap_language("luau", "/a/MAIN.LUAU")
    assert_equal "Luau", remap_language(nil, "/a/main.luau")
  end

  def test_non_authoritative_extensions_still_trust_the_client
    assert_equal "Lua", remap_language("Lua", "/a/main.lua")
    assert_equal "C++", remap_language("C++", "/a/foo.h")
    assert_nil remap_language(nil, "/a/noext")
  end

  private

  def remap_language(language, entity)
    HeartbeatPayloadRemapper.remap_language(language:, entity:)[:language]
  end
end
