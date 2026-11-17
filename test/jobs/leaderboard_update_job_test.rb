require "test_helper"

class LeaderboardUpdateJobTest < ActiveJob::TestCase
  setup do
    Rails.cache.clear
  end

  teardown do
    Rails.cache.clear
  end

  test "perform uses rolling 24 hours and excludes browser editor and last-project heartbeats" do
    coded_user = create_user(username: "lb_job_coded", github_uid: "GH_LEADERBOARD_JOB_CODED")
    browser_only_user = create_user(username: "lb_job_browser", github_uid: "GH_LEADERBOARD_JOB_BROWSER")
    old_user = create_user(username: "lb_job_old", github_uid: "GH_LEADERBOARD_JOB_OLD")

    create_heartbeat_pair(user: coded_user, started_at: 23.hours.ago, editor: "vscode")
    create_heartbeat_pair(user: coded_user, started_at: 2.hours.ago, editor: "firefox")
    create_heartbeat_pair(user: coded_user, started_at: 1.hour.ago, editor: "vscode", project: "<<LAST_PROJECT>>")
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

  test "rebuilds exclude opted out users and restore them after rejoining" do
    user = create_user(username: "lb_opt_out", github_uid: "GH_LB_OPT_OUT")
    create_heartbeat_pair(user: user, started_at: 1.hour.ago, editor: "vscode")

    LeaderboardUpdateJob.perform_now(:daily, Date.current, force_update: true)
    board = Leaderboard.find_by!(start_date: Date.current, period_type: :daily)
    assert_equal [ user.id ], board.entries.pluck(:user_id)

    user.update!(leaderboard_opt_out: true)
    LeaderboardUpdateJob.perform_now(:daily, Date.current, force_update: true)
    assert_empty board.entries.reload

    user.update!(leaderboard_opt_out: false)
    LeaderboardUpdateJob.perform_now(:daily, Date.current, force_update: true)
    assert_equal [ user.id ], board.entries.reload.pluck(:user_id)
  end

  test "perform counts AI coding at 90% whether or not it was prompted" do
    freeze_time do
      agent_user = create_user(username: "lb_job_agent", github_uid: "GH_LEADERBOARD_JOB_AGENT")

      start = 3.hours.ago
      (0..40).each { |minute| create_ai_heartbeat(user: agent_user, time: start + minute.minutes) }

      LeaderboardUpdateJob.perform_now(:daily, Date.current, force_update: true)

      board = Leaderboard.find_by!(start_date: Date.current, period_type: :daily, timezone_utc_offset: nil)
      entry = board.entries.find_by!(user_id: agent_user.id)

      assert_equal (40.minutes * 0.9).to_i, entry.total_seconds
      assert_equal (40.minutes * 0.1).to_i, entry.discounted_ai_seconds
    end
  end

  test "perform deflates AI coding on a curve that resets each day" do
    freeze_time do
      human_user = create_user(username: "lb_job_human", github_uid: "GH_LEADERBOARD_JOB_HUMAN")
      mixed_user = create_user(username: "lb_job_mixed", github_uid: "GH_LEADERBOARD_JOB_MIXED")
      split_user = create_user(username: "lb_job_split", github_uid: "GH_LEADERBOARD_JOB_SPLIT")
      binge_user = create_user(username: "lb_job_binge", github_uid: "GH_LEADERBOARD_JOB_BINGE")

      date = Date.current
      day_one = (date - 3.days).beginning_of_day + 1.hour
      day_two = (date - 2.days).beginning_of_day + 1.hour

      create_session(user: human_user, start: day_one, hours: 6, category: "coding")
      create_session(user: mixed_user, start: day_one, hours: 2, category: "coding")
      create_session(user: mixed_user, start: day_one + 2.hours, hours: 6, category: "ai coding")
      create_session(user: split_user, start: day_one, hours: 6, category: "ai coding")
      create_session(user: split_user, start: day_two, hours: 6, category: "ai coding")
      create_session(user: binge_user, start: day_one, hours: 12, category: "ai coding")

      LeaderboardUpdateJob.perform_now(:last_7_days, date, force_update: true)

      board = Leaderboard.find_by!(start_date: date, period_type: :last_7_days, timezone_utc_offset: nil)
      totals = board.entries.pluck(:user_id, :total_seconds).to_h
      six_hours_of_ai = LeaderboardEntry.credited_ai_seconds(6.hours.to_i)

      assert_equal 6.hours.to_i, totals[human_user.id]
      assert_equal (2.hours + six_hours_of_ai).round, totals[mixed_user.id]
      # Day two's first heartbeat also earns the capped two minute gap since day one.
      assert_equal (six_hours_of_ai + LeaderboardEntry.credited_ai_seconds(6.hours.to_i + 2.minutes.to_i)).round, totals[split_user.id]
      assert_equal LeaderboardEntry.credited_ai_seconds(12.hours.to_i).round, totals[binge_user.id]
      assert_operator totals[split_user.id], :>, totals[binge_user.id]
      assert_equal 12.hours.to_i - totals[binge_user.id], board.entries.find_by!(user_id: binge_user.id).discounted_ai_seconds
      assert_equal 0, board.entries.find_by!(user_id: human_user.id).discounted_ai_seconds
    end
  end

  private

  # A heartbeat every two minutes for hours, so every gap counts in full.
  def create_session(user:, start:, hours:, category:)
    (0..(hours * 30)).each do |i|
      create(:heartbeat, user: user,
        entity: "src/session.rb",
        type: "file",
        category: category,
        editor: category == "ai coding" ? "claude-code" : "vscode",
        time: (start + (i * 2).minutes).to_f,
        project: "leaderboard-job-test",
        source_type: :test_entry
      )
    end
  end

  def create_ai_heartbeat(user:, time:)
    create(:heartbeat, user: user,
      entity: "src/agent.rb",
      type: "file",
      category: "ai coding",
      editor: "claude-code",
      time: time.to_f,
      project: "leaderboard-job-test",
      source_type: :test_entry
    )
  end

  def create_user(username:, github_uid:)
    create(:user,
      username: username,
      github_uid: github_uid
    )
  end

  def create_heartbeat_pair(user:, started_at:, editor:, project: "leaderboard-job-test")
    create(:heartbeat, user: user,
      entity: "src/#{editor}.rb",
      type: "file",
      category: "coding",
      editor: editor,
      time: started_at.to_f,
      project: project,
      source_type: :test_entry
    )
    create(:heartbeat, user: user,
      entity: "src/#{editor}.rb",
      type: "file",
      category: "coding",
      editor: editor,
      time: (started_at + 2.minutes).to_f,
      project: project,
      source_type: :test_entry
    )
  end
end
