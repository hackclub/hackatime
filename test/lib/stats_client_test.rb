require "test_helper"

class StatsClientTest < ActiveSupport::TestCase
  test "duration_grouped posts integer timestamps and normalizes grouped entries" do
    captured_request = nil
    response_body = {
      "groups" => [
        { "name" => "Rust", "total_seconds" => 1200 },
        { "name" => "Ruby", "total_seconds" => 300 }
      ]
    }

    response = with_stubbed_post(
      handler: lambda do |path, body|
        captured_request = [ path, body ]
        response_body
      end
    ) do
      StatsClient.duration_grouped(
        group_by: :language,
        user_id: 42,
        start_time: Time.utc(2026, 1, 2, 3, 4, 5),
        end_time: Time.utc(2026, 1, 2, 4, 5, 6)
      )
    end

    assert_equal({ "Rust" => 1200, "Ruby" => 300 }, response["groups"])
    assert_equal "/api/v1/duration/grouped", captured_request[0]
    assert_equal Time.utc(2026, 1, 2, 3, 4, 5).to_i, captured_request[1][:start_time]
    assert_equal Time.utc(2026, 1, 2, 4, 5, 6).to_i, captured_request[1][:end_time]
    assert_equal "language", captured_request[1][:group_by]
  end

  test "duration preserves fractional timestamps for exclusive upper bounds" do
    captured_request = nil

    with_stubbed_post(
      handler: lambda do |path, body|
        captured_request = [ path, body ]
        { "total_seconds" => 120 }
      end
    ) do
      StatsClient.duration(
        user_id: 42,
        start_time: Time.utc(2026, 1, 2, 3, 4, 5),
        end_time: Time.utc(2026, 1, 2, 4, 5, 6).to_f - 1e-6
      )
    end

    assert_equal "/api/v1/duration", captured_request[0]
    assert_equal Time.utc(2026, 1, 2, 3, 4, 5).to_i, captured_request[1][:start_time]
    assert_operator captured_request[1][:end_time], :<, Time.utc(2026, 1, 2, 4, 5, 6).to_f
    assert_in_delta Time.utc(2026, 1, 2, 4, 5, 6).to_f - 1e-6, captured_request[1][:end_time], 1e-6
  end

  test "exclusive_end_time nudges integer timestamps but preserves fractional ones" do
    exact = Time.utc(2026, 1, 2, 4, 5, 6)
    fractional = exact.to_f - 1e-6

    assert_in_delta exact.to_f - 1e-6, StatsClient.exclusive_end_time(exact), 1e-6
    assert_in_delta fractional, StatsClient.exclusive_end_time(fractional), 1e-6
  end

  test "normalizes streak, daily duration, and profile payloads" do
    streaks = with_stubbed_post({ "streaks" => [ { "user_id" => 42, "streak_count" => 7 } ] }) do
      StatsClient.streaks(user_ids: [ 42 ])
    end
    durations = with_stubbed_post({
      "durations" => [
        { "date" => "2026-01-02", "total_seconds" => 600 },
        { "date" => "2026-01-03", "total_seconds" => 900 }
      ]
    }) do
      StatsClient.daily_durations(user_id: 42, timezone: "UTC")
    end
    profile = with_stubbed_post({
      "today_seconds" => 600,
      "week_seconds" => 1800,
      "all_seconds" => 3600,
      "top_languages" => [ { "name" => "Rust", "total_seconds" => 1800 } ],
      "top_projects" => [ { "name" => "hackatime", "total_seconds" => 1200 } ],
      "top_projects_month" => [ { "name" => "hackatime", "total_seconds" => 1200 } ],
      "top_editors" => [ { "name" => "zed", "total_seconds" => 900 } ]
    }) do
      StatsClient.profile_stats(user_id: 42, timezone: "UTC")
    end

    assert_equal({ "42" => 7 }, streaks["streaks"])
    assert_equal({ "2026-01-02" => 600, "2026-01-03" => 900 }, durations["durations"])
    assert_equal({ "Rust" => 1800 }, profile["top_languages"])
    assert_equal({ "hackatime" => 1200 }, profile["top_projects"])
    assert_equal([ { "project" => "hackatime", "duration" => 1200 } ], profile["top_projects_month"])
    assert_equal({ "zed" => 900 }, profile["top_editors"])
  end

  test "normalizes grouped results inside duration batches" do
    response = with_stubbed_post({
      "results" => {
        "total" => { "total_seconds" => 1200 },
        "languages" => {
          "groups" => [
            { "name" => "Rust", "total_seconds" => 900 },
            { "name" => "Ruby", "total_seconds" => 300 }
          ]
        }
      }
    }) do
      StatsClient.duration_batch(
        user_id: 42,
        start_time: Time.utc(2026, 1, 2),
        end_time: Time.utc(2026, 1, 3),
        queries: [
          { id: "total", type: "ungrouped" },
          { id: "languages", type: "grouped", group_by: "language" }
        ]
      )
    end

    assert_equal 1200, response.dig("results", "total", "total_seconds")
    assert_equal(
      { "Rust" => 900, "Ruby" => 300 },
      response.dig("results", "languages", "groups")
    )
  end

  private

  def with_stubbed_post(response = nil, handler: nil)
    original_post = StatsClient.method(:post)
    stubbed_post = handler || ->(_path, _body) { response }

    StatsClient.singleton_class.send(:define_method, :post, &stubbed_post)
    StatsClient.singleton_class.send(:private, :post)

    yield
  ensure
    StatsClient.singleton_class.send(:define_method, :post, original_post)
    StatsClient.singleton_class.send(:private, :post)
  end
end
