require "test_helper"

class Admin::AuditSubmissionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @builder = create(:user, username: "teen_builder")
    @builder.update!(hca_id: "hca-builder-#{@builder.id}") if @builder.respond_to?(:hca_id=)

    @admin = create(:user, admin_level: :admin)
    @admin.update!(hca_id: "hca-admin-#{@admin.id}") if @admin.respond_to?(:hca_id=)

    @viewer = create(:user, admin_level: :viewer)
    @viewer.update!(hca_id: "hca-viewer-#{@viewer.id}") if @viewer.respond_to?(:hca_id=)

    @submission = @builder.audit_submissions.create!(
      project_hash: "1" * 64,
      project_name: "cnc-controller",
      program_slug: "ysws-pcb",
      bundle_sha256: "2" * 64,
      submitted_hours: 4.5,
      chain_verified: true,
      git_push_verified: true
    )
  end

  test "admin inspects workbench index/show and approves audit submission" do
    sign_in_as(@admin)

    get admin_audit_submissions_path
    assert_response :ok

    get admin_audit_submission_path(@submission)
    assert_response :ok

    patch admin_audit_submission_path(@submission), params: {
      review_status: "approved",
      approved_hours: 4.5,
      reviewer_notes: "Clean Ed25519 chain and verified GitHub commits."
    }
    assert_redirected_to admin_audit_submission_path(@submission)
    @submission.reload
    assert_equal "approved", @submission.review_status
    assert_equal 4.5, @submission.approved_hours.to_f
    assert_equal @admin.id, @submission.reviewed_by_id
  end

  test "viewer admin can inspect audit submission read-only but cannot mutate status" do
    sign_in_as(@viewer)

    get admin_audit_submission_path(@submission)
    assert_response :ok

    patch admin_audit_submission_path(@submission), params: {
      review_status: "approved",
      approved_hours: 4.5
    }
    assert_response :not_found
    assert_equal "pending", @submission.reload.review_status
  end
end
