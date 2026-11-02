require "test_helper"

class CleanupExpiredSessionsJobTest < ActiveJob::TestCase
  test "removes stale sessions and keeps recent sessions" do
    travel_to Time.current do
      stale = WebSession.create!(session_id: SecureRandom.hex, data: { "user_id" => 1 }, updated_at: 15.days.ago)
      recent = WebSession.create!(session_id: SecureRandom.hex, data: { "user_id" => 2 }, updated_at: 13.days.ago)

      2.times { CleanupExpiredSessionsJob.perform_now }

      assert_not WebSession.exists?(stale.id)
      assert WebSession.exists?(recent.id)
    end
  end
end
