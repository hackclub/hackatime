require "test_helper"

class AnonymizeUserServiceTest < ActiveSupport::TestCase
  test "anonymization clears profile identity fields" do
    user = User.create!(
      username: "anon_user_#{SecureRandom.hex(4)}",
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
end
