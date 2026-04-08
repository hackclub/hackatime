require "test_helper"

class Cache::UsageSocialProofJobTest < ActiveJob::TestCase
  setup do
    Rails.cache.clear
    Heartbeat.delete_all
  end

  teardown do
    Heartbeat.delete_all
    Rails.cache.clear
  end

  test "prefers the past hour message when enough users were recently active" do
    travel_to Time.utc(2026, 1, 14, 12, 0, 0) do
      6.times { create_coding_heartbeat(30.minutes.ago) }

      message = Cache::UsageSocialProofJob.perform_now(force_reload: true)

      assert_equal "In the past hour, 6 Hack Clubbers have coded with Hackatime.", message
    end
  end

  test "falls back to the past day message when the hour count is too small" do
    travel_to Time.utc(2026, 1, 14, 12, 0, 0) do
      4.times { create_coding_heartbeat(30.minutes.ago) }
      2.times { create_coding_heartbeat(6.hours.ago) }

      message = Cache::UsageSocialProofJob.perform_now(force_reload: true)

      assert_equal "In the past day, 6 Hack Clubbers have coded with Hackatime.", message
    end
  end

  private

  def create_coding_heartbeat(time)
    user = User.create!(timezone: "UTC")
    user.heartbeats.create!(
      category: "coding",
      project: "usage-social-proof",
      editor: "vscode",
      time: time.to_f,
      source_type: :test_entry
    )
  end
end
