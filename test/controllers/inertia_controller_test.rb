require "test_helper"

class InertiaControllerTest < ActionDispatch::IntegrationTest
  test "pure descendants inherit the Inertia layout" do
    get extensions_path

    assert_response :success
    assert_inertia_component "Extensions/Index"
    assert_select "html[data-theme]"
    assert_select "[data-page]"
  end

  test "mixed descendants apply the layout only to Inertia responses" do
    get signin_path

    assert_response :success
    assert_inertia_component "Auth/SignIn"
    assert_select "html[data-theme]"
    assert_select "[data-page]"

    get currently_hacking_count_static_pages_path

    assert_response :success
    assert_equal "application/json", response.media_type
    assert response.parsed_body.key?("count")
    assert_not response.body.start_with?("<!DOCTYPE html>")
  end
end
