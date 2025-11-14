require "test_helper"

class SlackActivityDigestServiceTest < ActiveSupport::TestCase
  def setup
    @original_timeout = Heartbeat.heartbeat_timeout_duration
    Heartbeat.heartbeat_timeout_duration(1.hour)

    @user = User.create!(
      slack_uid: "U123TEST",
      username: "testuser",
      timezone: "UTC",
      slack_neighborhood_channel: "C123TEST"
    )

    @subscription = SlackActivityDigestSubscription.create!(
      slack_channel_id: "C123TEST",
      timezone: "UTC",
      delivery_hour: 10,
      enabled: true
    )
  end

  def teardown
    Heartbeat.heartbeat_timeout_duration(@original_timeout)
    Heartbeat.delete_all
    SlackActivityDigestSubscription.delete_all
    User.delete_all
  end

  def test_build_includes_top_user_and_project
    travel_to Time.utc(2024, 5, 2, 12, 0, 0) do
      create_heartbeat(@user, project: "ShipIt", seconds: 3600, occurred_at: Time.utc(2024, 5, 1, 18, 0, 0))
      create_heartbeat(@user, project: "ShipIt", seconds: 1200, occurred_at: Time.utc(2024, 5, 1, 19, 0, 0))

      result = SlackActivityDigestService.new(subscription: @subscription, as_of: Time.current).build

      assert_equal 4800, result.total_seconds
      assert_equal [ @user.id ], result.active_user_ids

      blocks_text = result.blocks.map { |block| block.dig(:text, :text) }.compact.join("\n")
      assert_includes blocks_text, "ShipIt"
      assert_includes blocks_text, "testuser"
    end
  end

  def test_build_handles_no_activity
    travel_to Time.utc(2024, 5, 2, 12, 0, 0) do
      result = SlackActivityDigestService.new(subscription: @subscription, as_of: Time.current).build

      assert_equal 0, result.total_seconds
      fallback = result.blocks.last.dig(:text, :text)
      assert_match(/No coding activity/, fallback)
    end
  end

  private

  def create_heartbeat(user, project:, seconds:, occurred_at:)
    steps = [ (seconds / 60).to_i, 1 ].max
    step_seconds = seconds / steps.to_f

    (steps + 1).times do |index|
      ts = occurred_at.to_i + (index * step_seconds).round
      Heartbeat.create!(
        user: user,
        time: ts,
        project: project,
        source_type: :direct_entry
      )
    end
  end
end
