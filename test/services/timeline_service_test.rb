require "test_helper"

class TimelineServiceTest < ActiveSupport::TestCase
  DATE = Date.new(2026, 8, 10)

  test "total_coded_time matches Heartbeat.duration_seconds for the user's day" do
    user = User.create!(timezone: "UTC")
    day_start = DATE.in_time_zone("UTC").beginning_of_day.to_f

    create_heartbeat(user, time: day_start + 3600)
    create_heartbeat(user, time: day_start + 3660)
    create_heartbeat(user, time: day_start + 4060)

    service = TimelineService.new(date: DATE, selected_user_ids: [ user.id ])
    data = service.timeline_data.find { |d| d[:user].id == user.id }

    expected = Heartbeat.where(user_id: user.id, deleted_at: nil)
                        .where("time >= ? AND time <= ?", day_start, day_start + 1.day.to_i - 1)
                        .duration_seconds

    assert_equal 180, data[:total_coded_time], "60s gap plus 400s gap capped at 120s"
    assert_equal expected, data[:total_coded_time]
  end

  test "total_coded_time only counts heartbeats within the user's local day" do
    user = User.create!(timezone: "UTC")
    day_start = DATE.in_time_zone("UTC").beginning_of_day.to_f

    create_heartbeat(user, time: day_start - 60)
    create_heartbeat(user, time: day_start + 60)
    create_heartbeat(user, time: day_start + 120)

    service = TimelineService.new(date: DATE, selected_user_ids: [ user.id ])
    data = service.timeline_data.find { |d| d[:user].id == user.id }

    assert_equal 60, data[:total_coded_time], "the heartbeat before midnight must not contribute"
  end

  test "commit_markers uses the user's timezone to pick the day" do
    user = User.create!(timezone: "Asia/Tokyo")

    # 01:00 on Aug 10 in Tokyo is 16:00 on Aug 9 UTC: outside the server-zone
    # day but inside the user's day, so it must appear.
    in_user_day = Time.utc(2026, 8, 9, 16, 0, 0)
    # 20:00 Aug 10 UTC is 05:00 on Aug 11 in Tokyo: inside the server-zone day
    # but outside the user's day, so it must not appear.
    outside_user_day = Time.utc(2026, 8, 10, 20, 0, 0)

    create_commit(user, sha: "a" * 40, committed_at: in_user_day)
    create_commit(user, sha: "b" * 40, committed_at: outside_user_day)

    service = TimelineService.new(date: DATE, selected_user_ids: [ user.id ])
    timestamps = service.commit_markers.map { |c| c[:timestamp] }

    assert_includes timestamps, in_user_day.to_f
    assert_not_includes timestamps, outside_user_day.to_f
  end

  test "commit_markers skips commits without a GitHub URL" do
    user = User.create!(timezone: "UTC")
    committed_at = DATE.in_time_zone("UTC").beginning_of_day + 2.hours

    Commit.create!(sha: "c" * 40, user_id: user.id, created_at: committed_at,
                   github_raw: { "commit" => { "committer" => { "date" => committed_at.iso8601 } } })

    service = TimelineService.new(date: DATE, selected_user_ids: [ user.id ])

    assert_empty service.commit_markers
  end

  private

  def create_heartbeat(user, time:)
    user.heartbeats.create!(
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      editor: "vscode",
      language: "Ruby",
      time: time,
      project: "alpha",
      source_type: :test_entry
    )
  end

  def create_commit(user, sha:, committed_at:)
    Commit.create!(
      sha: sha,
      user_id: user.id,
      created_at: committed_at,
      github_raw: {
        "html_url" => "https://github.com/example/repo/commit/#{sha}",
        "stats" => { "additions" => 1, "deletions" => 2 },
        "commit" => { "committer" => { "date" => committed_at.iso8601 } }
      }
    )
  end
end
