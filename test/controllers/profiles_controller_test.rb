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

  test "shared project page reads its stats bundle from serving tables" do
    user = User.create!(username: "shared_#{SecureRandom.hex(3)}", timezone: "UTC")
    user.project_repo_mappings.create!(project_name: "public-project", public_shared_at: Time.current)
    base = Time.utc(2026, 7, 10, 12)
    create_heartbeat(
      user: user, time: base.to_f, project: "public-project", language: "Ruby",
      entity: "app/main.rb", branch: "main", category: "coding", source_type: :test_entry
    )
    create_heartbeat(
      user: user, time: (base + 90.seconds).to_f, project: "public-project", language: "Ruby",
      entity: "app/main.rb", branch: "main", category: "coding", source_type: :test_entry
    )
    raw_duration_queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql = payload[:sql].to_s
      raw_duration_queries << sql if sql.match?(/\bFROM\s+heartbeats\b/i) && sql.include?("lagInFrame")
    end

    get profile_project_path(username: user.username, project_name: "public-project")

    assert_response :success
    assert_inertia_component "Projects/PublicShow"
    assert_equal "1m 30s", inertia_page.dig("props", "total_time_label")
    assert_equal 1, inertia_page.dig("props", "file_count")
    assert_equal({ "Ruby" => 90 }, inertia_page.dig("props", "language_stats"))
    assert_empty raw_duration_queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
