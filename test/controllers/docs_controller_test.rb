require "test_helper"

class DocsControllerTest < ActionDispatch::IntegrationTest
  # -- llms.txt --

  test "llms.txt returns 200 with text/plain content type" do
    get "/llms.txt"

    assert_response :success
    assert_match %r{text/plain}, response.content_type
  end

  test "llms.txt contains Hackatime heading" do
    get "/llms.txt"

    assert_includes response.body, "# Hackatime"
  end

  test "llms.txt contains link to llms-full.txt" do
    get "/llms.txt"

    assert_includes response.body, "llms-full.txt"
  end

  test "llms.txt lists popular editors" do
    get "/llms.txt"

    DocsController::POPULAR_EDITORS.each do |name, slug|
      assert_includes response.body, name, "Expected llms.txt to list popular editor #{name}"
      assert_includes response.body, slug, "Expected llms.txt to include slug #{slug}"
    end
  end

  test "llms.txt contains Getting Started links" do
    get "/llms.txt"

    assert_includes response.body, "quick-start"
    assert_includes response.body, "installation"
    assert_includes response.body, "configuration"
  end

  # -- llms-full.txt --

  test "llms-full.txt returns 200 with text/plain content type" do
    get "/llms-full.txt"

    assert_response :success
    assert_match %r{text/plain}, response.content_type
  end

  test "llms-full.txt contains complete documentation heading" do
    get "/llms-full.txt"

    assert_includes response.body, "# Hackatime - Complete Documentation"
  end

  test "llms-full.txt inlines getting started docs" do
    get "/llms-full.txt"

    # The full text should contain the actual content from docs files, not just links
    quick_start_content = File.read(Rails.root.join("docs", "getting-started", "quick-start.md"))
    first_line = quick_start_content.lines.first&.strip

    assert_includes response.body, first_line,
      "Expected llms-full.txt to inline quick-start.md content"
  end

  test "llms-full.txt inlines editor setup guides" do
    get "/llms-full.txt"

    # Should contain content from at least one editor doc
    DocsController::ALL_EDITORS.each do |name, slug|
      file_path = Rails.root.join("docs", "editors", "#{slug}.md")
      next unless File.exist?(file_path)

      assert_includes response.body, name,
        "Expected llms-full.txt to include editor #{name}"
      break # One editor is enough to confirm inlining works
    end
  end

  test "llms-full.txt inlines OAuth docs" do
    get "/llms-full.txt"

    oauth_content = File.read(Rails.root.join("docs", "oauth", "oauth-apps.md"))
    first_line = oauth_content.lines.first&.strip

    assert_includes response.body, first_line,
      "Expected llms-full.txt to inline oauth-apps.md content"
  end

  test "llms-full.txt lists key features" do
    get "/llms-full.txt"

    assert_includes response.body, "Key Features"
    assert_includes response.body, "Automatic time tracking"
  end

  # -- docs show .md format --

  test "docs show returns markdown content when requested with .md format" do
    get "/docs/getting-started/quick-start.md"

    assert_response :success
    assert_match %r{text/markdown}, response.content_type
  end

  test "docs show .md format returns raw markdown content" do
    get "/docs/getting-started/quick-start.md"

    expected_content = File.read(Rails.root.join("docs", "getting-started", "quick-start.md"))
    assert_equal expected_content, response.body
  end

  test "docs show returns HTML/Inertia by default" do
    get "/docs/getting-started/quick-start"

    assert_response :success
    assert_inertia_component "Docs/Show"
  end
end
