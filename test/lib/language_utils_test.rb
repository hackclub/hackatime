require "test_helper"

class LanguageUtilsTest < Minitest::Test
  def setup
    LanguageUtils.instance_variable_set(:@data, nil)
    LanguageUtils.instance_variable_set(:@extension_map, nil)
    LanguageUtils.instance_variable_set(:@alias_map, nil)
    LanguageUtils.instance_variable_set(:@filename_map, nil)
    LanguageUtils.instance_variable_set(:@unambiguous_extension_map, nil)
    LanguageUtils.instance_variable_set(:@unambiguous_filename_map, nil)
  end

  def teardown
    LanguageUtils.instance_variable_set(:@data, nil)
    LanguageUtils.instance_variable_set(:@extension_map, nil)
    LanguageUtils.instance_variable_set(:@alias_map, nil)
    LanguageUtils.instance_variable_set(:@filename_map, nil)
    LanguageUtils.instance_variable_set(:@unambiguous_extension_map, nil)
    LanguageUtils.instance_variable_set(:@unambiguous_filename_map, nil)
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

  def test_fill_missing_language_trusts_present_client_languages
    assert_equal "Lua", LanguageUtils.fill_missing_language("Lua", entity: "/a/main.luau")
    assert_equal "Lua", LanguageUtils.fill_missing_language("Lua", entity: "/a/main.lua")
    assert_equal "C++", LanguageUtils.fill_missing_language("C++", entity: "/a/foo.h")
    assert_equal "Ruby", LanguageUtils.fill_missing_language(nil, entity: "/a/main.rb")
    assert_nil LanguageUtils.fill_missing_language(nil, entity: "/a/main.rs")
    assert_nil LanguageUtils.fill_missing_language(nil, entity: "/a/noext")
  end
end
