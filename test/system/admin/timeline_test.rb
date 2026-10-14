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

  test "ignores stale searches and selects a user with the listbox keyboard behavior" do
    slow_user = create(:user, username: "timeline_slow_result")
    fast_user = create(:user, username: "timeline_fast_result")

    visit admin_timeline_path(date: DATE.iso8601)
    track_timeline_searches(delay_query: slow_user.username)

    search = find("#timeline-user-search")
    search.set slow_user.username
    assert_selector "body[data-timeline-slow-response-ready='true']"

    search.set fast_user.username
    option = find("[role='option']", text: fast_user.display_name)
    assert_equal "listbox", find("##{search[:'aria-controls']}")[:role]

    sleep 1.1
    assert_selector "[role='option']", text: fast_user.display_name
    assert_no_selector "[role='option']", text: slow_user.display_name

    search.send_keys :down
    option = find("[role='option']", text: fast_user.display_name)
    assert_equal "true", option[:"aria-selected"]
    assert_equal option[:id], search[:"aria-activedescendant"]

    search.send_keys :enter
    assert_no_selector "[role='listbox']"
    assert_text fast_user.display_name
    assert_includes find("input[name='user_ids']", visible: false).value,
      fast_user.id.to_s
  end

  test "Enter selects the first result without another request" do
    user = create(:user, username: "timeline_enter_result")

    visit admin_timeline_path(date: DATE.iso8601)
    track_timeline_searches

    search = find("#timeline-user-search")
    search.set user.username
    option = find("[role='option']", text: user.display_name)
    assert_equal "false", option[:"aria-selected"]

    request_count = page.evaluate_script("window.__timelineSearchQueries.length")
    search.send_keys :enter
    sleep 0.3

    assert_equal request_count,
      page.evaluate_script("window.__timelineSearchQueries.length")
    assert_no_selector "[role='listbox']"
    assert_includes find("input[name='user_ids']", visible: false).value,
      user.id.to_s
  end

  test "Enter during debounce selects the pending first result with one request" do
    user = create(:user, username: "timeline_pending")

    visit admin_timeline_path(date: DATE.iso8601)
    track_timeline_searches

    search = find("#timeline-user-search")
    search.set user.username
    search.send_keys :enter

    assert_selector \
      "input[name='user_ids'][value='#{@admin.id},#{user.id}']",
      visible: false
    sleep 0.3
    assert_equal [ user.username ],
      page.evaluate_script("window.__timelineSearchQueries")
    assert_no_selector "[role='listbox']"
  end

  test "Escape aborts a delayed search without reopening results" do
    user = create(:user, username: "timeline_escape")

    visit admin_timeline_path(date: DATE.iso8601)
    track_timeline_searches(delay_query: user.username)

    search = find("#timeline-user-search")
    search.set user.username
    assert_selector "body[data-timeline-slow-response-ready='true']"

    search.send_keys :escape
    assert_selector "body[data-timeline-search-aborted='true']"
    sleep 1.1

    assert_equal "false", search[:"aria-expanded"]
    assert_no_selector "[role='listbox']"
    assert_equal [ user.username ],
      page.evaluate_script("window.__timelineSearchQueries")
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

  def track_timeline_searches(delay_query: nil)
    page.execute_script(<<~JS)
      const originalFetch = window.fetch.bind(window);
      window.__timelineSearchQueries = [];
      window.fetch = async (...args) => {
        const requestUrl = typeof args[0] === "string" ? args[0] : args[0].url;
        const url = new URL(requestUrl, window.location.origin);
        if (url.pathname !== "/admin/timeline/search_users") {
          return originalFetch(...args);
        }

        const query = url.searchParams.get("query");
        window.__timelineSearchQueries.push(query);
        args[1]?.signal?.addEventListener("abort", () => {
          document.body.dataset.timelineSearchAborted = "true";
        });
        const response = await originalFetch(...args);
        if (query === #{delay_query.to_json}) {
          document.body.dataset.timelineSlowResponseReady = "true";
          await new Promise((resolve) => setTimeout(resolve, 1_000));
        }
        return response;
      };
    JS
  end

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
