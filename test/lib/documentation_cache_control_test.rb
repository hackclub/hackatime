require "test_helper"

class DocumentationCacheControlTest < ActiveSupport::TestCase
  test "requires revalidation for mutable documentation files" do
    middleware = DocumentationCacheControl.new(->(_) { [ 200, { "cache-control" => "public, max-age=31536000" }, [] ] })

    %w[/docs /docs/editors/vim /docs.md /docs-sitemap.xml /llms.txt /og/docs.png].each do |path|
      _, headers, = middleware.call("REQUEST_METHOD" => "GET", "PATH_INFO" => path)

      assert_equal "public, max-age=0, must-revalidate", headers["cache-control"]
    end
  end

  test "preserves caching for fingerprinted assets" do
    middleware = DocumentationCacheControl.new(->(_) { [ 200, { "cache-control" => "public, max-age=31536000" }, [] ] })

    _, headers, = middleware.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/_astro/app.abc123.js")

    assert_equal "public, max-age=31536000", headers["cache-control"]
  end
end
