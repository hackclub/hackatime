require "test_helper"

class LeaderboardUpdateJobTest < ActiveJob::TestCase
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "perform uses rolling 24 hours and excludes browser editor heartbeats" do
    coded_user = create_user(username: "lb_job_coded", github_uid: "GH_LEADERBOARD_JOB_CODED")
    browser_only_user = create_user(username: "lb_job_browser", github_uid: "GH_LEADERBOARD_JOB_BROWSER")
    old_user = create_user(username: "lb_job_old", github_uid: "GH_LEADERBOARD_JOB_OLD")

    create_heartbeat_pair(user: coded_user, started_at: 23.hours.ago, editor: "vscode")
    create_heartbeat_pair(user: coded_user, started_at: 2.hours.ago, editor: "firefox")
    create_heartbeat_pair(user: browser_only_user, started_at: 1.hour.ago, editor: "firefox")
    create_heartbeat_pair(user: old_user, started_at: 25.hours.ago, editor: "vscode")

    LeaderboardUpdateJob.perform_now(:daily, Date.current, force_update: true)

    board = Leaderboard.find_by!(
      start_date: Date.current,
      period_type: :daily,
      timezone_utc_offset: nil
    )

    assert_equal [ coded_user.id ], board.entries.order(:user_id).pluck(:user_id)
    assert_equal 120, board.entries.find_by!(user_id: coded_user.id).total_seconds
    assert_operator board.generation_duration_seconds, :>=, 1
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
      project: "leaderboard-job-test",
      source_type: :test_entry
    )
    user.heartbeats.create!(
      entity: "src/#{editor}.rb",
      type: "file",
      category: "coding",
      editor: editor,
      time: (started_at + 2.minutes).to_f,
      project: "leaderboard-job-test",
      source_type: :test_entry
    )
  end
end
