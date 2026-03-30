require "test_helper"

class Api::V1::BadgesControllerTest < ActionDispatch::IntegrationTest
  test "ignores alias lists that collapse to the primary project" do
    user = User.create!(
      timezone: "UTC",
      username: "badge_user_#{SecureRandom.hex(4)}",
      allow_public_stats_lookup: true
    )
    user.heartbeats.create!(
      entity: "src/hackatime.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "hackatime",
      source_type: :test_entry
    )

    duration_calls = []

    original_duration = StatsClient.method(:duration)
    StatsClient.singleton_class.send(:define_method, :duration) do |**args|
      duration_calls << args
      { "total_seconds" => 600 }
    end

    begin
      get "/api/v1/badge/#{user.username}/hackatime", params: { aliases: "hackatime" }
    ensure
      StatsClient.singleton_class.send(:define_method, :duration, original_duration)
    end

    assert_response :redirect
    assert_equal 1, duration_calls.size
    assert_equal(
      {
        user_id: user.id,
        project: "hackatime"
      },
      duration_calls.first
    )
    assert_includes response.location, "10m"
  end
end
