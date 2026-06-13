require "test_helper"

class EventParticipationBackfillTest < ActiveSupport::TestCase
  test "backfills event participation from historical heartbeats" do
    user = User.create!(timezone: "UTC")
    user.update_columns(event_participation: 0, event_participation_backfilled: false)
    user.heartbeats.create!(
      entity: "src/high_seas.rb",
      type: "file",
      category: "coding",
      time: Time.zone.parse("2024-12-15 12:00:00").to_f,
      project: "hackatime",
      source_type: :test_entry
    )

    assert_equal 1, EventParticipationBackfill.call(scope: User.where(id: user.id))

    user.reload
    assert user.event_participation_backfilled?
    assert user.event_participation.set?(:high_seas)
    assert_not user.event_participation.set?(:scrapyard)
  end
end
