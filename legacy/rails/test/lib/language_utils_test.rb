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
end
