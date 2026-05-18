require "test_helper"

class Admin::DeletionRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ultraadmin = User.create!(timezone: "UTC", admin_level: :ultraadmin, username: "ultraadmin")
    @superadmin = User.create!(timezone: "UTC", admin_level: :superadmin, username: "superadmin")
    @target = User.create!(timezone: "UTC", username: "delete_me")
  end

  # new

  test "new is accessible to ultraadmins" do
    sign_in_as(@ultraadmin)
    get new_admin_deletion_request_path
    assert_response :success
  end

  test "new is not accessible to superadmins" do
    sign_in_as(@superadmin)
    get new_admin_deletion_request_path
    assert_response :redirect
  end

  # confirm

  test "confirm finds user by id" do
    sign_in_as(@ultraadmin)
    get confirm_admin_deletion_requests_path, params: { q: @target.id }
    assert_response :success
  end

  test "confirm finds user by username" do
    sign_in_as(@ultraadmin)
    get confirm_admin_deletion_requests_path, params: { q: @target.username }
    assert_response :success
  end

  test "confirm finds user by email" do
    @target.email_addresses.create!(email: "delete_me@example.com", source: :signing_in)
    sign_in_as(@ultraadmin)
    get confirm_admin_deletion_requests_path, params: { q: "delete_me@example.com" }
    assert_response :success
  end

  test "confirm redirects to new when user not found" do
    sign_in_as(@ultraadmin)
    get confirm_admin_deletion_requests_path, params: { q: "no_such_user" }
    assert_redirected_to new_admin_deletion_request_path
  end

  test "confirm is not accessible to superadmins" do
    sign_in_as(@superadmin)
    get confirm_admin_deletion_requests_path, params: { q: @target.id }
    assert_response :redirect
  end

  # create

  test "create makes a pending deletion request when username matches" do
    sign_in_as(@ultraadmin)
    assert_difference "DeletionRequest.count", 1 do
      post admin_deletion_requests_path, params: {
        deletion_request: { user_id: @target.id, confirm_username: @target.username }
      }
    end
    assert_redirected_to admin_deletion_requests_path
    req = DeletionRequest.last
    assert_equal @target, req.user
    assert req.pending?
    assert_includes req.reason_details, "manually requested"
  end

  test "create with instant approves and enqueues job" do
    sign_in_as(@ultraadmin)
    assert_difference "DeletionRequest.count", 1 do
      post admin_deletion_requests_path, params: {
        deletion_request: { user_id: @target.id, confirm_username: @target.username, instant: "1" }
      }
    end
    assert_redirected_to admin_deletion_requests_path
    req = DeletionRequest.last
    assert req.approved?
    assert req.scheduled_deletion_at <= Time.current
    assert_includes req.reason_details, "speedy"
  end

  test "create bounces back to confirm when username doesn't match" do
    sign_in_as(@ultraadmin)
    assert_no_difference "DeletionRequest.count" do
      post admin_deletion_requests_path, params: {
        deletion_request: { user_id: @target.id, confirm_username: "wrong_username" }
      }
    end
    assert_redirected_to confirm_admin_deletion_requests_path(q: @target.id)
  end

  test "create bounces back to confirm when user already has an active request" do
    DeletionRequest.create_for_user!(@target)
    sign_in_as(@ultraadmin)
    assert_no_difference "DeletionRequest.count" do
      post admin_deletion_requests_path, params: {
        deletion_request: { user_id: @target.id, confirm_username: @target.username }
      }
    end
    assert_redirected_to confirm_admin_deletion_requests_path(q: @target.id)
  end

  test "create redirects to new when user_id is invalid" do
    sign_in_as(@ultraadmin)
    assert_no_difference "DeletionRequest.count" do
      post admin_deletion_requests_path, params: {
        deletion_request: { user_id: 0, confirm_username: "whatever" }
      }
    end
    assert_redirected_to new_admin_deletion_request_path
  end

  test "create is not accessible to superadmins" do
    sign_in_as(@superadmin)
    assert_no_difference "DeletionRequest.count" do
      post admin_deletion_requests_path, params: {
        deletion_request: { user_id: @target.id, confirm_username: @target.username }
      }
    end
    assert_response :redirect
  end
end
