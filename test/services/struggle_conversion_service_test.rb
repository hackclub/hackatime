require "test_helper"

class StruggleConversionServiceTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
  end

  def create_unconverted_window(project_hash:, start_unix:, raw: 300, convertible: 242, sp: 8.05)
    eff_mult = sp < 2.0 ? 0.0 : [ sp.to_f / 10.0, 1.0 ].min.round(3)
    @user.struggle_windows.create!(
      project_hash: project_hash,
      project_name: "demo-game",
      window_start: Time.at(start_unix).utc,
      raw_seconds: raw,
      convertible_seconds: convertible,
      credited_seconds: 0,
      struggle_points: sp,
      diversity_multiplier: 1.15,
      verify_multiplier: 1.0,
      effective_multiplier: eff_mult,
      effective_multiplier_milli: (eff_mult * 1000).round,
      provenance_mask: 3,
      primary_language: "C++",
      ai_harness: "antigravity",
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: "0123456789abcdef0123456789abcdef",
      chain_hash: format("%064x", start_unix),
      signature: "x" * 64
    )
  end

  def create_coding_heartbeat(ts)
    @user.heartbeats.create!(
      project: "demo-game",
      language: "C++",
      editor: "vscode",
      category: "coding",
      entity: "/src/main.cpp",
      type: "file",
      is_write: true,
      source_type: :direct_entry,
      time: ts.to_f
    )
  end

  test "Option A converts unconverted windows using per-window exact cap and prevents double conversion" do
    proj = "a" * 64
    w1 = create_unconverted_window(project_hash: proj, start_unix: 1_795_089_600, raw: 300, convertible: 300, sp: 19.55)
    w2 = create_unconverted_window(project_hash: proj, start_unix: 1_795_089_900, raw: 300, convertible: 242, sp: 8.05)

    assert_equal 0, w1.credited_seconds
    assert_nil w1.converted_at

    first = StruggleConversionService.call(user: @user, project_hash: proj)
    assert first.success?
    assert_equal 2, first.converted_count
    assert_equal 542, first.conversion.total_credited_seconds
    assert_equal 600, first.conversion.total_raw_seconds
    assert_in_delta 27.60, first.conversion.total_sp_converted.to_f, 0.01

    assert_equal 300, w1.reload.credited_seconds
    assert_equal 242, w2.reload.credited_seconds
    assert_not_nil w1.converted_at
    assert_equal first.conversion.id, w1.struggle_conversion_id

    # Verify converted time was credited into main Hackatime heartbeats under "struggle point time"
    struggle_hbs = @user.heartbeats.where(category: "struggle point time")
    assert struggle_hbs.count >= 2
    assert_equal "demo-game", struggle_hbs.first.project
    assert_equal "C++", struggle_hbs.first.language
    assert_equal "antigravity", struggle_hbs.first.editor
    assert_equal 542, struggle_hbs.duration_seconds
    assert_equal 542, @user.heartbeats.leaderboard_eligible.duration_seconds

    dashboard = DashboardStats.new(user: @user).filterable_dashboard_data
    assert_equal 542, dashboard[:total_time]
    assert_equal 542, dashboard["category_stats"]["struggle point time"]
    assert_equal 542, dashboard[:coding_category_stats]["struggle point time"]

    # Second attempt on the exact same project MUST fail with zero double-claiming
    second = StruggleConversionService.call(user: @user, project_hash: proj)
    refute second.success?
    assert_equal 0, second.converted_count
  end

  test "conversion alongside existing normal coding heartbeats adds exact struggle point time without gap inflation" do
    proj = "b" * 64
    base = Time.current.beginning_of_day.to_i + 3600

    # User coded normally for 120s earlier in the day
    create_coding_heartbeat(base)
    create_coding_heartbeat(base + 60)
    create_coding_heartbeat(base + 120)

    # 10 minutes later, user did 200s of verified agentic struggle work
    create_unconverted_window(project_hash: proj, start_unix: base + 720, raw: 300, convertible: 200, sp: 6.7)

    res = StruggleConversionService.call(user: @user, project_hash: proj)
    assert res.success?
    assert_equal 200, res.conversion.total_credited_seconds

    by_cat = Heartbeat.attributed_durations_by(@user.heartbeats, :category)
    assert_equal 120, by_cat["coding"]
    assert_equal 200, by_cat["struggle point time"]
    assert_equal 320, @user.heartbeats.duration_seconds
  end

  test "overlapping normal heartbeats covering a full 5-minute window do not inflate receipt or steal coding credit" do
    proj = "c" * 64
    base = Time.current.beginning_of_day.to_i + 7200

    (0..5).each { |step| create_coding_heartbeat(base + (step * 60)) }
    assert_equal 300, @user.heartbeats.duration_seconds

    window = create_unconverted_window(project_hash: proj, start_unix: base, raw: 300, convertible: 300, sp: 12.0)

    res = StruggleConversionService.call(user: @user, project_hash: proj)
    assert res.success?
    assert_equal 0, res.conversion.total_credited_seconds
    assert_equal 0, window.reload.credited_seconds
    assert_equal 0, @user.heartbeats.where(category: "struggle point time").count

    by_cat = Heartbeat.attributed_durations_by(@user.heartbeats, :category)
    assert_equal 300, by_cat["coding"]
    assert_nil by_cat["struggle point time"]
    assert_equal 300, @user.heartbeats.duration_seconds
  end

  test "partially overlapping normal heartbeats credit only the uncovered portion of the window" do
    proj = "d" * 64
    base = Time.current.beginning_of_day.to_i + 10_800

    # Normal coding covers the first 2 minutes (120s) of the 5-minute window
    create_coding_heartbeat(base)
    create_coding_heartbeat(base + 60)
    create_coding_heartbeat(base + 120)

    window = create_unconverted_window(project_hash: proj, start_unix: base, raw: 300, convertible: 300, sp: 12.0)

    res = StruggleConversionService.call(user: @user, project_hash: proj)
    assert res.success?
    assert_equal 180, res.conversion.total_credited_seconds
    assert_equal 180, window.reload.credited_seconds

    by_cat = Heartbeat.attributed_durations_by(@user.heartbeats, :category)
    assert_equal 120, by_cat["coding"]
    assert_equal 180, by_cat["struggle point time"]
    assert_equal 300, @user.heartbeats.duration_seconds
  end

  test "multiple windows straddling a normal coding block preserve both coding and struggle point time" do
    proj = "e" * 64
    base = Time.current.beginning_of_day.to_i + 14_400

    # Normal coding runs continuously across [base + 300, base + 900] (600s)
    (0..10).each { |step| create_coding_heartbeat(base + 300 + (step * 60)) }
    assert_equal 600, @user.heartbeats.duration_seconds

    w1 = create_unconverted_window(project_hash: proj, start_unix: base, raw: 300, convertible: 300, sp: 12.0)
    w2 = create_unconverted_window(project_hash: proj, start_unix: base + 900, raw: 300, convertible: 300, sp: 12.0)

    res = StruggleConversionService.call(user: @user, project_hash: proj)
    assert res.success?
    assert_equal 600, res.conversion.total_credited_seconds
    assert_equal 300, w1.reload.credited_seconds
    assert_equal 300, w2.reload.credited_seconds

    by_cat = Heartbeat.attributed_durations_by(@user.heartbeats, :category)
    assert_equal 600, by_cat["coding"]
    assert_equal 600, by_cat["struggle point time"]
    assert_equal 1200, @user.heartbeats.duration_seconds
  end
end
