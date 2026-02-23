require "test_helper"

class AnonymizeUserServiceTest < ActiveSupport::TestCase
  test "anonymization clears profile identity fields" do
    user = User.create!(
      username: "anon_#{SecureRandom.hex(4)}",
      display_name_override: "Custom Name",
      profile_bio: "Bio",
      profile_github_url: "https://github.com/hackclub",
      profile_twitter_url: "https://x.com/hackclub",
      profile_bluesky_url: "https://bsky.app/profile/hackclub.com",
      profile_linkedin_url: "https://linkedin.com/in/hackclub",
      profile_discord_url: "https://discord.gg/hackclub",
      profile_website_url: "https://hackclub.com"
    )

    AnonymizeUserService.call(user)

    user.reload
    assert_nil user.display_name_override
    assert_nil user.profile_bio
    assert_nil user.profile_github_url
    assert_nil user.profile_twitter_url
    assert_nil user.profile_bluesky_url
    assert_nil user.profile_linkedin_url
    assert_nil user.profile_discord_url
    assert_nil user.profile_website_url
  end

  test "anonymization destroys goals" do
    user = User.create!(username: "ag_#{SecureRandom.hex(4)}")
    user.goals.create!(period: "day", target_seconds: 600, languages: [ "Ruby" ], projects: [ "alpha" ])

    assert_equal 1, user.goals.count

    AnonymizeUserService.call(user)

    assert_equal 0, user.goals.count
  end

  test "anonymization removes api keys and sign-in tokens" do
    user = User.create!(username: "cleanup_#{SecureRandom.hex(4)}")
    user.api_keys.create!(name: "primary")
    user.sign_in_tokens.create!(auth_type: :email)

    assert_equal 1, user.api_keys.count
    assert_equal 1, user.sign_in_tokens.count

    AnonymizeUserService.call(user)

    assert_equal 0, user.api_keys.count
    assert_equal 0, user.sign_in_tokens.count
  end

  test "anonymization soft deletes active heartbeats" do
    user = User.create!(username: "hb_cleanup_#{SecureRandom.hex(4)}")
    heartbeat = user.heartbeats.create!(
      entity: "src/app.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "anonymize",
      source_type: :test_entry
    )

    AnonymizeUserService.call(user)

    assert heartbeat.reload.deleted_at.present?
  end
end
