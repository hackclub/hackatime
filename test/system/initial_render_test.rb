require "application_system_test_case"

class InitialRenderTest < ApplicationSystemTestCase
  test "initial document uses critical styles while full styles and fonts load" do
    visit root_path

    initial_style = find("style[data-initial-vite-stylesheet=critical]", visible: :all)
    assert_includes initial_style.native.text_content, "html.fonts-pending"
    assert_includes initial_style.native.text_content, "size-adjust:92%"
    assert_equal 3, initial_style.native.text_content.scan("@font-face").size

    assert_selector "link[rel=stylesheet][href*='/vite-test/assets/application-']", visible: :all
    assert_selector "link[rel=stylesheet][href*='/vite-test/assets/inertia-']", visible: :all
    assert_match(/<noscript>.*application-.*\.css.*<\/noscript>/m, page.html)
    assert_no_selector "html.fonts-pending", visible: :all
  end

  test "critical styles keep the pending initial render visible" do
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.add_init_script(script: <<~JS)
        FontFaceSet.prototype.load = () => new Promise(() => {});
      JS
      playwright_page.route(/\/vite-test\/.*\.css/, ->(route, _request) { route.abort })
    end

    visit root_path

    assert_selector "html.fonts-pending", visible: :all
    assert_selector "h1", visible: true
    assert_operator page.evaluate_script("document.body.getBoundingClientRect().width"), :>, 500
    assert_not_equal "rgba(0, 0, 0, 0)", page.evaluate_script("getComputedStyle(document.body).backgroundColor")
    assert_includes page.evaluate_script("getComputedStyle(document.body).fontFamily"), "Spline Sans Fallback"
    assert_equal "0", page.evaluate_script("getComputedStyle(document.body).getPropertyValue('--tw-translate-y')")
    assert_equal "solid", page.evaluate_script("getComputedStyle(document.body).getPropertyValue('--tw-border-style')")
  end
end
