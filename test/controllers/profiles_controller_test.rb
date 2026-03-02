require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "shows inertia profile page for existing user" do
    user = User.create!(username: "profile_user_#{SecureRandom.hex(4)}", profile_bio: "I like building tools")

    get profile_path(user.username)

    assert_response :success
    assert_inertia_component "Profiles/Show"
    assert_inertia_prop "profile_visible", true
    assert_equal "I like building tools", inertia_page.dig("props", "profile", "bio")
  end

  test "returns inertia not found for unknown profile" do
    get profile_path("missing_#{SecureRandom.hex(4)}")

    assert_response :not_found
    assert_inertia_component "Errors/NotFound"
  end

  test "shows bio and socials while hiding stats for private profiles" do
    user = User.create!(
      username: "priv_#{SecureRandom.hex(3)}",
      allow_public_stats_lookup: false,
      profile_bio: "Private stats, public profile.",
      profile_github_url: "https://github.com/hackclub"
    )

    get profile_path(user.username)

    assert_response :success
    assert_inertia_component "Profiles/Show"
    assert_inertia_prop "profile_visible", false
    assert_equal "Private stats, public profile.", inertia_page.dig("props", "profile", "bio")
    assert_equal "GitHub", inertia_page.dig("props", "profile", "social_links", 0, "label")
    assert_nil inertia_page.dig("props", "stats")
  end

  test "shows stats to owner even when profile is private" do
    user = User.create!(
      username: "own_#{SecureRandom.hex(3)}",
      allow_public_stats_lookup: false
    )
    sign_in_as(user)

    get profile_path(user.username)

    assert_response :success
    assert_inertia_component "Profiles/Show"
    assert_inertia_prop "profile_visible", true
    assert_inertia_prop "is_own_profile", true
  end
end
