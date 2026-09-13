require "application_system_test_case"

class InitialRenderTest < ApplicationSystemTestCase
  test "initial document inlines compiled styles while retaining external assets" do
    visit root_path

    initial_styles = all("style[data-initial-vite-stylesheet]", visible: :all)
    assert_equal %w[application inertia], initial_styles.map { |style| style["data-initial-vite-stylesheet"] }
    assert_includes initial_styles.first.native.text_content, "html.fonts-pending"
    assert_includes initial_styles.first.native.text_content, "size-adjust:92%"
    assert_includes initial_styles.last.native.text_content, "@font-face"

    assert_selector "link[rel=stylesheet][href*='/vite-test/assets/application-']", visible: :all
    assert_selector "link[rel=stylesheet][href*='/vite-test/assets/inertia-']", visible: :all
    assert page.evaluate_script('document.fonts.check(\'400 1em "Spline Sans Variable"\', "AĀ")')
    assert_no_selector "html.fonts-pending", visible: :all
  end
end
