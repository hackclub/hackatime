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
end
