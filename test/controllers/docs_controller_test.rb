require "test_helper"

class DocsControllerTest < ActionDispatch::IntegrationTest
  # -- docs show .md format --

  test "docs show returns markdown content when requested with .md format" do
    get "/docs/getting-started/quick-start.md"

    assert_response :success
    assert_match %r{text/markdown}, response.content_type

    expected_content = File.read(Rails.root.join("docs", "getting-started", "quick-start.md"))
    assert_equal expected_content, response.body
  end

  test "docs show returns HTML/Inertia by default" do
    get "/docs/getting-started/quick-start"

    assert_response :success
    assert_inertia_component "Docs/Show"
  end

  test "docs index marks editor catalogs as once props" do
    get docs_path

    assert_response :success
    assert_inertia_component "Docs/Index"

    page = inertia_page
    assert_equal "popular_editors", page.dig("onceProps", "popular_editors", "prop")
    assert_equal "all_editors", page.dig("onceProps", "all_editors", "prop")
  end
end
