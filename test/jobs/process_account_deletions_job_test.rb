require "test_helper"

class ProcessAccountDeletionsJobTest < ActiveSupport::TestCase
  test "deletion completes for users with invalid legacy timezones" do
    requests = [ nil, "", "Eastern Time (US & Canada)", "Invalid/Timezone" ].map do |timezone|
      user = create(:user, :with_email, display_name_override: "Delete me")
      create(:api_key, user: user)
      request = create(:deletion_request, user: user, status: :approved, scheduled_deletion_at: 1.day.ago)
      user.update_column(:timezone, timezone)
      request
    end

    ProcessAccountDeletionsJob.perform_now

    requests.each do |request|
      assert request.reload.completed?, "Deletion did not complete for user #{request.user_id}"
      assert_not_nil request.completed_at
      user = request.user.reload
      assert_equal "UTC", user.timezone
      assert_equal "deleted_user_#{user.id}", user.username
      assert_nil user.display_name_override
      assert_empty user.api_keys
      assert user.email_addresses.first!.source_preserved_for_deletion?
    end
  end
end
