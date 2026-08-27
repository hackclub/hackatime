require "application_system_test_case"

class AdminTimelineTest < ApplicationSystemTestCase
  DATE = Date.new(2026, 8, 10)

  setup do
    @admin = create(:user, :with_email, :admin)
    sign_in_as(@admin)
  end

  test "positions spans and commit markers on the grid" do
    day_start = DATE.in_time_zone("UTC").beginning_of_day.to_f
    # One span from 02:00 to 02:08 (gaps below the 10 minute timeout).
    create_heartbeat(@admin, time: day_start + 2.hours.to_i)
    create_heartbeat(@admin, time: day_start + 2.hours.to_i + 4.minutes.to_i)
    create_heartbeat(@admin, time: day_start + 2.hours.to_i + 8.minutes.to_i)
    create_commit(@admin, committed_at: Time.at(day_start + 3.hours.to_i).utc)

    visit admin_timeline_path(date: DATE.iso8601)

    # 8 minutes of wall time, but each 4 minute gap is capped at the 2 minute
    # heartbeat timeout, so 4m of coded time.
    assert_text "4m coded"

    # 02:00 = header (120px) + 2 hours * 128px; 8 minutes = 17.07px.
    span = find("div[title*='Duration:']")
    assert_includes span[:style], "top: 376px"
    assert_includes span[:style], "height: 17.07px"

    # 03:00 in the first column: left = 80 + 93, top = 120 + 3 * 128.
    marker = find("a", text: "+1")
    assert_includes marker[:style], "left: 173px"
    assert_includes marker[:style], "top: 504px"
  end

  # test "shows a NOW line and centers the grid on the current time when viewing today" do
  #   visit admin_timeline_path

  #   assert_text "NOW"

  #   scroller = find("main .overflow-y-auto")
  #   assert page.evaluate_script("arguments[0].scrollTop", scroller) > 0,
  #     "grid should auto-scroll towards the current time"
  #   expected = page.evaluate_script(<<~JS, scroller)
  #     (() => {
  #       const el = arguments[0];
  #       const now = new Date();
  #       const target = 120 + (now.getUTCHours() + now.getUTCMinutes() / 60) * 128;
  #       return Math.abs(el.scrollTop - Math.max(0, target - el.clientHeight / 2)) < 130;
  #     })()
  #   JS
  #   assert expected, "grid should be centered near the current time of day"
  # end

  private

  def create_heartbeat(user, time:)
    create(
      :heartbeat,
      user: user,
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

  def create_commit(user, committed_at:)
    create(
      :commit,
      sha: "d" * 40,
      user_id: user.id,
      created_at: committed_at,
      github_raw: {
        "html_url" => "https://github.com/example/repo/commit/dd",
        "stats" => { "additions" => 1, "deletions" => 2 },
        "commit" => { "committer" => { "date" => committed_at.iso8601 } }
      }
    )
  end
end
