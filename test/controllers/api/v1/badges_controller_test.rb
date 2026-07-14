require "test_helper"

class Api::V1::BadgesControllerTest < ActionDispatch::IntegrationTest
  test "show reads project duration from serving tables" do
    user = User.create!(slack_uid: "UBADGE#{SecureRandom.hex(4)}", timezone: "UTC", allow_public_stats_lookup: true)
    create_heartbeat(user:, project: "hackatime", time: Time.utc(2026, 7, 1, 9, 0, 0).to_f)
    create_heartbeat(user:, project: "hackatime", time: Time.utc(2026, 7, 1, 9, 10, 0).to_f)

    heartbeat_queries = nil
    serving_queries = collect_serving_queries do
      heartbeat_queries = collect_heartbeat_queries do
        get "/api/v1/badge/#{user.slack_uid}/hackatime"
      end
    end

    assert_response :temporary_redirect
    assert_includes response.headers.fetch("Location"), "2m"
    assert_empty heartbeat_queries
    assert_equal 2, serving_queries.size
  end

  test "show preserves bad request for projects with heartbeats but no duration" do
    user = User.create!(slack_uid: "UZERO#{SecureRandom.hex(4)}", timezone: "UTC", allow_public_stats_lookup: true)
    create_heartbeat(user:, project: "hackatime", time: Time.utc(2026, 7, 1, 9, 0, 0).to_f)

    heartbeat_queries = collect_heartbeat_queries do
      get "/api/v1/badge/#{user.slack_uid}/hackatime"
    end

    assert_response :bad_request
    assert_empty heartbeat_queries
  end

  test "show sums project aliases with one additional serving query" do
    user = User.create!(slack_uid: "UALIAS#{SecureRandom.hex(4)}", timezone: "UTC", allow_public_stats_lookup: true)
    base = Time.utc(2026, 7, 1, 9, 0, 0)
    create_heartbeat(user:, project: "hackatime", time: base.to_f)
    create_heartbeat(user:, project: "hackatime", time: (base + 2.minutes).to_f)
    create_heartbeat(user:, project: "legacy", time: (base + 5.minutes).to_f)
    create_heartbeat(user:, project: "legacy", time: (base + 7.minutes).to_f)

    serving_queries = collect_serving_queries do
      get "/api/v1/badge/#{user.slack_uid}/hackatime", params: { aliases: "legacy,missing" }
    end

    assert_response :temporary_redirect
    assert_includes response.headers.fetch("Location"), "4m"
    assert_equal 3, serving_queries.size
  end

  private

  def create_heartbeat(user:, project:, time:)
    super(
      user: user,
      source_type: :direct_entry,
      time: time,
      project: project,
      category: "coding"
    )
  end

  def collect_heartbeat_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql].to_s
      queries << sql if sql.match?(/\bFROM\s+`?heartbeats`?\b/i)
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def collect_serving_queries
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.clickhouse_serving") do |*, payload|
      queries << payload.fetch(:sql)
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
