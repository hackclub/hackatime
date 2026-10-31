require "application_system_test_case"

class ErrorsTest < ApplicationSystemTestCase
  test "error pages render without the app layout props" do
    visit "/404"

    assert_text "Page Not Found"
  end
end
