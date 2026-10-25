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

  test "perform counts AI coding only within 25 minutes of the latest prompt" do
    freeze_time do
      agent_user = create_user(username: "lb_job_agent", github_uid: "GH_LEADERBOARD_JOB_AGENT")
      early_prompt_user = create_user(username: "lb_job_early_prompt", github_uid: "GH_LEADERBOARD_JOB_EARLY")

      # Prompt, then the agent keeps working for 40 minutes. The heartbeat at
      # exactly +25 minutes still counts; the ones after it do not.
      prompt_at = 3.hours.ago
      create_ai_heartbeat(user: agent_user, time: prompt_at, ai_prompt_length: 42)
      (1..40).each { |minute| create_ai_heartbeat(user: agent_user, time: prompt_at + minute.minutes) }

      # The prompt comes before the rolling 24 hours start but still credits
      # the first 15 minutes of the range.
      range_start = 24.hours.ago
      create_ai_heartbeat(user: early_prompt_user, time: range_start - 10.minutes, ai_prompt_length: 42)
      (1..20).each { |minute| create_ai_heartbeat(user: early_prompt_user, time: range_start + minute.minutes) }

      LeaderboardUpdateJob.perform_now(:daily, Date.current, force_update: true)

      board = Leaderboard.find_by!(start_date: Date.current, period_type: :daily, timezone_utc_offset: nil)
      agent_entry = board.entries.find_by!(user_id: agent_user.id)
      early_prompt_entry = board.entries.find_by!(user_id: early_prompt_user.id)

      assert_equal 25.minutes.to_i, agent_entry.total_seconds
      assert_equal 15.minutes.to_i, agent_entry.unprompted_ai_seconds
      assert_equal 14.minutes.to_i, early_prompt_entry.total_seconds
      assert_equal 5.minutes.to_i, early_prompt_entry.unprompted_ai_seconds
    end
  end

  private

  def create_ai_heartbeat(user:, time:, ai_prompt_length: nil)
    create(:heartbeat, user: user,
      entity: "src/agent.rb",
      type: "file",
      category: "ai coding",
      editor: "claude-code",
      time: time.to_f,
      project: "leaderboard-job-test",
      ai_prompt_length: ai_prompt_length,
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
