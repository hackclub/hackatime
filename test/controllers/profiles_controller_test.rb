require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "shows inertia profile page for existing user" do
    user = create(:user, username: "profile_user_#{SecureRandom.hex(4)}", profile_bio: "I like building tools")

    get profile_path(user.username)

    assert_response :success
    assert_inertia_component "Profiles/Show"
    assert_inertia_props profile_visible: true
    assert_equal "I like building tools", inertia.props.dig("profile", "bio")
  end

  test "shared projects get their own link preview card while unshared ones stay hidden" do
    user = create(:user, username: "proj_#{SecureRandom.hex(3)}")
    create(:project_repo_mapping, user: user, project_name: "shared-thing", public_shared_at: Time.current)
    create(:project_repo_mapping, user: user, project_name: "secret-thing")

    get profile_project_path(user.username, "shared-thing")

    assert_response :success
    assert_select "meta[property='og:title'][content=?]", "shared-thing by @#{user.username} | Hackatime"
    assert_select "meta[property='og:image'][content=?]", profile_project_og_image_url(username: user.username, project_name: "shared-thing")

    get profile_project_og_image_path(user.username, "secret-thing")

    assert_response :not_found
  end

  test "returns inertia not found for unknown profile" do
    get profile_path("missing_#{SecureRandom.hex(4)}")

    assert_response :not_found
    assert_inertia_component "Errors/NotFound"
  end

  test "shows bio and socials while hiding stats for private profiles" do
    user = create(:user,
      username: "priv_#{SecureRandom.hex(3)}",
      allow_public_stats_lookup: false,
      profile_bio: "Private stats, public profile.",
      profile_github_url: "https://github.com/hackclub"
    )

    get profile_path(user.username)

    assert_response :success
    assert_inertia_component "Profiles/Show"
    assert_inertia_props profile_visible: false
    assert_equal "Private stats, public profile.", inertia.props.dig("profile", "bio")
    assert_equal "GitHub", inertia.props.dig("profile", "social_links", 0, "label")
    assert_nil inertia.props["stats"]
  end

  test "shows stats to owner even when profile is private" do
    user = create(:user,
      username: "own_#{SecureRandom.hex(3)}",
      allow_public_stats_lookup: false
    )
    sign_in_as(user)

    get profile_path(user.username)

    assert_response :success
    assert_inertia_component "Profiles/Show"
    assert_inertia_props profile_visible: true, is_own_profile: true
  end
end
