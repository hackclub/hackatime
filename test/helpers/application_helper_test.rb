require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "display_editor_name shows IDLE in capitals" do
    assert_equal "IDLE", display_editor_name("idle")
  end
end
