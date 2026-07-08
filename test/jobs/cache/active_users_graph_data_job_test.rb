require "test_helper"

class Cache::ActiveUsersGraphDataJobTest < ActiveSupport::TestCase
  test "rounds fractional heartbeat seconds before hourly bucketing" do
    user = User.create!(timezone: "UTC")
    hour = 6.hours.ago.beginning_of_hour.to_i

    create_heartbeat(
      user: user,
      entity: "src/hour_boundary.rb",
      type: "file",
      category: "coding",
      editor: "vscode",
      language: "ruby",
      project: "hour-boundary",
      source_type: :test_entry,
      time: hour + 3599.6
    )

    result = Cache::ActiveUsersGraphDataJob.new.send(:calculate)

    assert_equal [ hour + 3600 ], result.map { |row| row[:hour].to_i }
    assert_equal 1, result.first[:users]
  end
end
