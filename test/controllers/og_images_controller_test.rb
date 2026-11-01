require "test_helper"

class OgImagesControllerTest < ActionDispatch::IntegrationTest
  test "serves a cacheable PNG card for a known page" do
    get og_image_path(page: "leaderboards")

    assert_response :success
    assert_equal "image/png", response.media_type
    assert response.body.start_with?("\x89PNG".b)
    assert_includes response.headers["Cache-Control"], "public"

    get og_image_path(page: "leaderboards"), headers: { "If-None-Match" => response.headers["ETag"] }

    assert_response :not_modified
  end

  test "returns not found for an unknown page" do
    get og_image_path(page: "nope")

    assert_response :not_found
  end
end
