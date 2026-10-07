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

  def test_idle_window_titles_fall_back_to_python
    [ "*main.py*", "main.py (3.14.2)", "IDLE Shell 3.14.0", "IDLE Shell 3.14.2", "Replace Dialog" ].each do |entity|
      assert_equal "Python", LanguageUtils.fill_missing_language(nil, entity:, editor: "idle"), entity
    end
    assert_equal "Python", LanguageUtils.fill_missing_language("Unknown", entity: "*main.py*", editor: "IDLE")
    assert_equal "Python", LanguageUtils.fill_missing_language("Groff", entity: "IDLE Shell 3.14.2", editor: "idle")
  end

  def test_browser_entities_never_guess_a_language_from_the_domain
    { "domain" => [ "github.com", "app.joinrunway.io", "http://10.0.0.1" ], "url" => [ "https://example.org/a.php" ] }.each do |type, entities|
      entities.each { |entity| assert_nil LanguageUtils.fill_missing_language(nil, entity:, type:), entity }
    end
    assert_equal "TypeScript", LanguageUtils.fill_missing_language("TypeScript", entity: "github.com", type: "domain")
    assert_equal "DIGITAL Command Language", LanguageUtils.fill_missing_language(nil, entity: "run.com", type: "file")
  end

  def test_browser_entities_drop_client_languages_guessed_from_the_host
    {
      "github.com" => "DIGITAL Command Language",
      "apstudents.collegeboard.org" => "Org",
      "http://192.168.0.1/" => "Groff",
      "https://67movies.nl/watch" => "newLisp",
      "github.com/acme/app/blob/main/build.sh" => "DIGITAL Command Language"
    }.each do |entity, language|
      assert_nil LanguageUtils.fill_missing_language(language, entity:, type: "url"), entity
    end
    assert_equal "Python", LanguageUtils.fill_missing_language("Python", entity: "github.com", type: "domain")
    assert_equal "Markdown", LanguageUtils.fill_missing_language("Markdown", entity: "github.com/acme/app/blob/main/README.md", type: "url")
    assert_equal "Org", LanguageUtils.fill_missing_language("Org", entity: "/notes/todo.org", type: "file")
  end

  def test_jetbrains_auto_detected_placeholder_is_detected_or_unknown
    assert_equal "Java", LanguageUtils.fill_missing_language("AUTO_DETECTED", entity: "/a/Main.java", editor: "intellijidea")
    assert_equal "Unknown", LanguageUtils.fill_missing_language("AUTO_DETECTED", entity: "/a/.gitkeep", editor: "intellijidea")
  end

  def test_idle_fallback_leaves_other_editors_alone
    assert_equal "Groff", LanguageUtils.fill_missing_language("Groff", entity: "IDLE Shell 3.14.2", editor: "terminal")
    assert_nil LanguageUtils.fill_missing_language(nil, entity: "*main.py*", editor: "terminal")
    assert_nil LanguageUtils.fill_missing_language(nil, entity: "*main.py*")
  end
end
