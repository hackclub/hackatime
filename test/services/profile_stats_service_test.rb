require "test_helper"

class ProfileStatsServiceTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  test "attributes duplicate timestamp peer gaps by stable id order" do
    user = User.create!(timezone: "UTC")
    base_time = Time.utc(2026, 4, 14, 9, 0, 0).to_f

    create_heartbeat(user, time: base_time, project: "seed")
    create_heartbeat(user, time: base_time + 60, project: "alpha")
    create_heartbeat(user, time: base_time + 60, project: "beta")

    stats = ProfileStatsService.new(user).stats

    assert_equal 60, stats[:top_projects]["alpha"]
    assert_not_equal 60, stats[:top_projects]["beta"]
  end

  private

  def create_heartbeat(user, time:, project:)
    user.heartbeats.create!(
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      editor: "vscode",
      time: time,
      project: project,
      source_type: :test_entry
    )
  end
end
