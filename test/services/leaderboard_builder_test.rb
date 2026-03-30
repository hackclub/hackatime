require "test_helper"

class LeaderboardBuilderTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "build_for_users excludes browser editor heartbeats and users without github" do
    coded_user = create_user(username: "lb_build_coded", github_uid: "GH_LEADERBOARD_BUILDER_CODED")
    browser_only_user = create_user(username: "lb_build_browser", github_uid: "GH_LEADERBOARD_BUILDER_BROWSER")
    no_github_user = create_user(username: "lb_build_nogithub", github_uid: nil)

    create_heartbeat_pair(user: coded_user, started_at: today_at(9, 0), editor: "vscode")
    create_heartbeat_pair(user: coded_user, started_at: today_at(10, 0), editor: "firefox")
    create_heartbeat_pair(user: browser_only_user, started_at: today_at(11, 0), editor: "firefox")
    create_heartbeat_pair(user: no_github_user, started_at: today_at(12, 0), editor: "vscode")

    board = LeaderboardBuilder.build_for_users(
      User.where(id: [ coded_user.id, browser_only_user.id, no_github_user.id ]),
      Date.current,
      "global",
      :daily
    )

    assert_equal [ coded_user.id ], board.entries.map(&:user_id)
    assert_equal 120, board.entries.first.total_seconds
    assert_equal "global", board.scope_name
  end

  private

  def create_user(username:, github_uid:)
    User.create!(
      username: username,
      github_uid: github_uid,
      timezone: "UTC"
    )
  end

  def create_heartbeat_pair(user:, started_at:, editor:)
    user.heartbeats.create!(
      entity: "src/#{editor}.rb",
      type: "file",
      category: "coding",
      editor: editor,
      time: started_at.to_f,
      project: "leaderboard-builder-test",
      source_type: :test_entry
    )
    user.heartbeats.create!(
      entity: "src/#{editor}.rb",
      type: "file",
      category: "coding",
      editor: editor,
      time: (started_at + 2.minutes).to_f,
      project: "leaderboard-builder-test",
      source_type: :test_entry
    )
  end

  def today_at(hour, minute)
    Time.current.change(hour: hour, min: minute, sec: 0)
  end
end
