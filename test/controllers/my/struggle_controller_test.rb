require "test_helper"

class My::StruggleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, username: "struggle_builder", allow_public_stats_lookup: true)
    @user.update!(hca_id: "hca-test-#{@user.id}") if @user.respond_to?(:hca_id=)
    @project_hash = "e" * 64
    @window = @user.struggle_windows.create!(
      project_hash: @project_hash,
      project_name: "hackatime-ai",
      window_start: Time.at(1_795_090_200).utc,
      raw_seconds: 300,
      convertible_seconds: 270,
      credited_seconds: 0,
      struggle_points: 18.5,
      diversity_multiplier: 1.15,
      verify_multiplier: 1.0,
      effective_multiplier: 0.90,
      effective_multiplier_milli: 900,
      provenance_mask: 3,
      primary_language: "C++",
      ai_harness: "antigravity",
      signal_counts: { "SIG_ARCH_STEER" => 2, "SIG_ERROR_LOOP" => 1 },
      prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
      server_nonce: "0" * 32,
      chain_hash: "1" * 64,
      signature: "x" * 64
    )
  end

  test "authenticated user inspects unconverted SP and manually converts via /my/struggle" do
    sign_in_as(@user)

    get my_struggle_path
    assert_response :ok
    assert_includes response.body, "Struggle Points"
    assert_includes response.body, "/my/struggle"

    assert_difference("StruggleConversion.count", 1) do
      post convert_my_struggle_path, params: { project_hash: @project_hash }
    end
    assert_redirected_to my_struggle_path
    assert_equal 270, @window.reload.credited_seconds
    assert_not_nil @window.converted_at

    # Second click cannot double-claim already converted windows
    assert_no_difference("StruggleConversion.count") do
      post convert_my_struggle_path, params: { project_hash: @project_hash }
    end
    assert_redirected_to my_struggle_path
    assert_equal 270, @window.reload.credited_seconds
  end

  test "summary and project totals aggregate the full queue while bounding the window preview list" do
    sign_in_as(@user)

    # Add 55 additional windows (56 total > PREVIEW_WINDOWS_PER_PROJECT = 50)
    base_unix = 1_795_090_500
    now = Time.current
    rows = 55.times.map do |i|
      {
        user_id: @user.id,
        project_hash: @project_hash,
        project_name: "hackatime-ai",
        window_start: Time.at(base_unix + (i * 300)).utc,
        raw_seconds: 300,
        convertible_seconds: 300,
        credited_seconds: 0,
        struggle_points: 10.0,
        diversity_multiplier: 1.0,
        verify_multiplier: 1.0,
        effective_multiplier: 1.0,
        effective_multiplier_milli: 1000,
        provenance_mask: 3,
        primary_language: "C++",
        ai_harness: "antigravity",
        signal_counts: {},
        prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
        server_nonce: "0" * 32,
        chain_hash: format("%064x", i + 100),
        signature: "x" * 64,
        created_at: now,
        updated_at: now
      }
    end
    StruggleWindow.insert_all!(rows)

    get my_struggle_path, headers: { "X-Inertia" => "true" }
    assert_response :ok
    props = JSON.parse(response.body).fetch("props")

    assert_equal 56, props["summary"]["unconverted_windows_count"]
    assert_equal 270 + (55 * 300), props["summary"]["convertible_seconds"]

    group = props["project_groups"].first
    assert_equal 56, group["windows_count"]
    assert_equal 270 + (55 * 300), group["convertible_seconds"]
    assert_equal true, group["has_more_windows"]
    assert_equal My::StruggleController::PREVIEW_WINDOWS_PER_PROJECT, group["windows"].size
  end

  test "renders public SVG Struggle Card badge reflecting converted verified hours" do
    StruggleConversionService.call(user: @user, project_hash: @project_hash)

    get "/api/v1/struggle_badge/#{@user.username}.svg"
    assert_response :ok
    assert_includes response.content_type, "image/svg+xml"
    assert_includes response.body, "HACKATIME AI // @struggle_builder"
    assert_includes response.body, "0.1h"
    assert_includes response.body, "C++"

    @user.update!(allow_public_stats_lookup: false)
    get "/api/v1/struggle_badge/#{@user.username}.svg"
    assert_response :not_found
  end

  test "hides forensic integrity logs from regular users while exposing clean JSON export" do
    @window.struggle_point_events.create!(
      user: @user,
      project_hash: @project_hash,
      project_name: "hackatime-ai",
      window_start: @window.window_start,
      signal_code: "SIG_ARCH_STEER",
      trigger_count: 2,
      raw_points: 6.0,
      awarded_points: 6.0,
      provenance_tier: "tier_b",
      persisted_diff_lines: 12,
      gate_status: "awarded"
    )
    @window.struggle_point_events.create!(
      user: @user,
      project_hash: @project_hash,
      project_name: "hackatime-ai",
      window_start: @window.window_start,
      signal_code: "SIG_VERIFY_EXEC",
      trigger_count: 5,
      raw_points: 15.0,
      awarded_points: 0.0,
      provenance_tier: "tier_a",
      persisted_diff_lines: 0,
      gate_status: "gated_autonomous_ai"
    )

    sign_in_as(@user)

    get my_struggle_path, headers: { "X-Inertia" => "true" }
    assert_response :ok
    props = JSON.parse(response.body).fetch("props")
    assert_equal false, props["can_view_integrity_details"]
    assert_equal [], props["recent_point_events"]
    assert_equal [ "SIG_ARCH_STEER" ], props["sp_breakdown"].map { |row| row["signal_code"] }
    assert_nil props["sp_breakdown"].first["gated_windows"]
    assert_nil props["sp_breakdown"].first["raw_points"]

    get export_my_struggle_path
    assert_response :ok
    assert_includes response.content_type, "application/json"
    assert_includes response.headers["Content-Disposition"], "attachment"
    exported = JSON.parse(response.body)
    assert_equal 1, exported["windows"].size
    assert_nil exported["point_events"]
    assert_nil exported["windows"].first["anomaly_flags"]

    @user.update!(admin_level: :admin)

    get my_struggle_path, headers: { "X-Inertia" => "true" }
    assert_response :ok
    admin_props = JSON.parse(response.body).fetch("props")
    assert_equal true, admin_props["can_view_integrity_details"]
    assert_equal 2, admin_props["recent_point_events"].size

    get export_my_struggle_path
    assert_response :ok
    admin_exported = JSON.parse(response.body)
    assert_equal 2, admin_exported["point_events"].size
    assert_equal [], admin_exported["windows"].first["anomaly_flags"]
  end
end
