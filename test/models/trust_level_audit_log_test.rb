require "test_helper"

class TrustLevelAuditLogTest < ActiveSupport::TestCase
  setup do
    @admin = create(:user, :admin)
    @log = create(:trust_level_audit_log, changed_by: @admin, previous_trust_level: :red, new_trust_level: :blue,
                                          reason: "Unbanned after", notes: nil)
  end

  test "only the author can edit, within the window" do
    assert @log.editable_by?(@admin)
    assert_not @log.editable_by?(create(:user, :superadmin))
    assert_not @log.editable_by?(nil)

    @log.update_column(:created_at, (TrustLevelAuditLog::EDIT_WINDOW + 1.minute).ago)
    assert_not @log.editable_by?(@admin)
  end

  test "an author who lost admin can no longer edit" do
    @admin.update_column(:admin_level, "viewer")
    assert_not @log.reload.editable_by?(@admin.reload)
  end

  test "amend keeps the first-written text across repeated edits" do
    @log.amend!(reason: "Unbanned after appeal", notes: "thread", edited_by: @admin)
    @log.amend!(reason: "Unbanned after appeal, shared machine", notes: "thread", edited_by: @admin)
    @log.reload

    assert_equal "Unbanned after appeal, shared machine", @log.reason
    assert_equal "Unbanned after", @log.original_reason
    assert_nil @log.original_notes
    assert_equal @admin, @log.edited_by
    assert @log.edited?
    assert_equal "blue", @log.new_trust_level
    assert_equal 2, @log.versions.where(event: "update").count
  end

  test "amend with unchanged text records nothing" do
    @log.amend!(reason: "Unbanned after", notes: nil, edited_by: @admin)

    assert_not @log.reload.edited?
    assert_nil @log.original_reason
  end
end
