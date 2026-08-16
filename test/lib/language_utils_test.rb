require "test_helper"

class LanguageUtilsTest < Minitest::Test
  def setup
    LanguageUtils.instance_variable_set(:@data, nil)
    LanguageUtils.instance_variable_set(:@extension_map, nil)
    LanguageUtils.instance_variable_set(:@alias_map, nil)
    LanguageUtils.instance_variable_set(:@filename_map, nil)
  end

  def teardown
    LanguageUtils.instance_variable_set(:@data, nil)
    LanguageUtils.instance_variable_set(:@extension_map, nil)
    LanguageUtils.instance_variable_set(:@alias_map, nil)
    LanguageUtils.instance_variable_set(:@filename_map, nil)
  end

  def test_custom_assembly_extensions_override_other_languages
    assert_equal "Assembly", LanguageUtils.detect_from_extension("foo.asm")
    assert_equal "Assembly", LanguageUtils.detect_from_extension("foo.a51")
    assert_equal "Assembly", LanguageUtils.detect_from_extension("foo.nasm")
    assert_equal "Assembly", LanguageUtils.detect_from_extension("foo.s")
    assert_equal "Assembly", LanguageUtils.detect_from_extension("foo.S")
  end

  def test_custom_language_additions
    assert_equal "AsciiDoc", LanguageUtils.detect_from_extension("foo.ad")
  end

  def test_custom_language_without_extension_conflict
    assert_equal "Lapse", LanguageUtils.find_name("Lapse")
  end

  def test_authoritative_extension_overrides_client_reported_language
    assert_equal "Luau", LanguageUtils.fill_missing_language("Lua", entity: "/a/main.luau")
    assert_equal "Luau", LanguageUtils.fill_missing_language("PLAIN_TEXT", entity: "/a/main.luau")
    assert_equal "Luau", LanguageUtils.fill_missing_language("luau", entity: "/a/MAIN.LUAU")
    assert_equal "Luau", LanguageUtils.fill_missing_language(nil, entity: "/a/main.luau")
  end

  def test_non_authoritative_extensions_still_trust_the_client
    assert_equal "Lua", LanguageUtils.fill_missing_language("Lua", entity: "/a/main.lua")
    assert_equal "C++", LanguageUtils.fill_missing_language("C++", entity: "/a/foo.h")
    assert_nil LanguageUtils.fill_missing_language(nil, entity: "/a/noext")
  end
end
