require "test_helper"

class SlackActivityDigestSubscriptionTest < ActiveSupport::TestCase
  def setup
    @subscription = SlackActivityDigestSubscription.new(
      slack_channel_id: "C123",
      timezone: "UTC",
      delivery_hour: 10
    )
  end

  def test_due_for_delivery_when_never_delivered
    travel_to Time.utc(2024, 5, 1, 11, 0, 0) do
      assert @subscription.due_for_delivery?
    end
  end

  def test_not_due_before_delivery_hour
    travel_to Time.utc(2024, 5, 1, 9, 59, 0) do
      refute @subscription.due_for_delivery?
    end
  end

  def test_not_due_when_already_sent_today
    @subscription.last_delivered_at = Time.utc(2024, 5, 1, 10, 0, 0)

    travel_to Time.utc(2024, 5, 1, 15, 0, 0) do
      refute @subscription.due_for_delivery?
    end
  end

  def test_due_next_day_after_hour
    @subscription.last_delivered_at = Time.utc(2024, 4, 30, 10, 5, 0)

    travel_to Time.utc(2024, 5, 1, 10, 1, 0) do
      assert @subscription.due_for_delivery?
    end
  end
end
