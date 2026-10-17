require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "display_editor_name shows IDLE in capitals" do
    assert_equal "IDLE", display_editor_name("idle")
  end

  test "display_editor_name shows DeepSeek Harness for the dsh parser output" do
    assert_equal "DeepSeek Harness", display_editor_name("deepseek-harness")
  end
end
