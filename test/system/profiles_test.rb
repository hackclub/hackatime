require "application_system_test_case"

class ProfilesTest < ApplicationSystemTestCase
  test "public profile renders visible bio" do
    user = User.create!(
      username: "prof_#{SecureRandom.hex(4)}",
      profile_bio: "Profile bio from system test",
      allow_public_stats_lookup: true
    )

    visit profile_path(user.username)

    assert_text "Profile bio from system test"
  end
end
