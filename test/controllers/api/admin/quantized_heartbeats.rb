require "test_helper"

class Api::Admin::V1::QuantizedHeartbeatsControllerTest < ActionDispatch::IntegrationTest
  test "returns quantized heartbeats with cursorpos and lineno for a user and date range" do
    user = User.create!(timezone: "UTC")
    create_heartbeat(user:, time: Time.utc(2025, 12, 15, 10, 0, 0).to_f, project: "Project1", category: "coding", cursorpos: 100, lineno: 10)
    create_heartbeat(user:, time: Time.utc(2025, 12, 15, 10, 1, 40).to_f, project: "Project1", category: "coding", cursorpos: nil, lineno: nil)
    create_heartbeat(user:, time: Time.utc(2025, 12, 15, 10, 3, 40).to_f, project: "Project1", category: "coding", cursorpos: 150, lineno: 15)
    create_heartbeat(user:, time: Time.utc(2025, 12, 16, 11, 0, 0).to_f, project: "Project1", category: "coding", cursorpos: 200, lineno: nil)
    create_heartbeat(user:, time: Time.utc(2025, 12, 17, 12, 0, 0).to_f, project: "Project1", category: "coding", cursorpos: nil, lineno: 20)

    params = {
      filter_by_user_id: user.id,
      start_date: "2025-12-15",
      end_date: "2025-12-16"
    }

    get "/api/admin/v1/quantized_heartbeats", params: params

    assert_response :success
    heartbeats = JSON.parse(response.body).fetch("quantized_heartbeats")

    assert_equal 4, heartbeats.length
    assert_equal [100, nil, 150, 200], heartbeats.map { |hb| hb["cursorpos"] }
    assert_equal [10, nil, 15, nil], heartbeats.map { |hb| hb["lineno"] }
  end

  private

  def create_heartbeat(user:, time:, project:, category:, cursorpos:, lineno:)
    Heartbeat.create!(
      user: user,
      source_type: :direct_entry,
      time: time,
      project: project,
      category: category,
      cursorpos: cursorpos,
      lineno: lineno
    )
  end
end
