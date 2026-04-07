require "test_helper"

class LeaderboardUpdateJobTest < ActiveJob::TestCase
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "perform excludes browser editor heartbeats from persisted leaderboard entries" do
    coded_user = create_user(username: "lb_job_coded", gitlab_uid: "GL_LEADERBOARD_JOB_CODED")
    browser_only_user = create_user(username: "lb_job_browser", github_uid: "GH_LEADERBOARD_JOB_BROWSER")

    create_heartbeat_pair(user: coded_user, started_at: today_at(9, 0), editor: "vscode")
    create_heartbeat_pair(user: coded_user, started_at: today_at(11, 0), editor: "firefox")
    create_heartbeat_pair(user: browser_only_user, started_at: today_at(13, 0), editor: "firefox")

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

  def create_user(username:, github_uid: nil, gitlab_uid: nil)
    User.create!(
      username: username,
      github_uid: github_uid,
      gitlab_uid: gitlab_uid,
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

  def today_at(hour, minute)
    Time.current.change(hour: hour, min: minute, sec: 0)
  end
end
