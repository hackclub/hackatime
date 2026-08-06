require "test_helper"

class ProcessAccountDeletionsJobTest < ActiveJob::TestCase
  test "anonymizes and completes a due approved request atomically" do
    user = User.create!
    deletion_request = DeletionRequest.create_for_user!(user)
    deletion_request.update!(status: :approved, scheduled_deletion_at: 1.minute.ago)

    ProcessAccountDeletionsJob.perform_now

    assert user.reload.anonymized?
    assert deletion_request.reload.completed?
    assert deletion_request.completed_at.present?
  end

  test "does not process a request cancelled before its locked transition" do
    user = User.create!
    deletion_request = DeletionRequest.create_for_user!(user)
    deletion_request.update!(status: :approved, scheduled_deletion_at: 1.minute.ago)
    assert deletion_request.cancel!

    ProcessAccountDeletionsJob.perform_now

    assert_not user.reload.anonymized?
    assert deletion_request.reload.cancelled?
  end

  test "completed requests cannot later report a successful cancellation" do
    user = User.create!
    deletion_request = DeletionRequest.create_for_user!(user)
    deletion_request.update!(status: :approved, scheduled_deletion_at: 1.minute.ago)
    ProcessAccountDeletionsJob.perform_now

    assert_not deletion_request.reload.cancel!
    assert deletion_request.completed?
  end
end
