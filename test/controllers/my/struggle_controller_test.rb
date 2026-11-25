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
end
