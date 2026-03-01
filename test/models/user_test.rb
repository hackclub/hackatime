require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "theme defaults to gruvbox dark" do
    user = User.new

    assert_equal "gruvbox_dark", user.theme
  end

  test "theme options include all supported themes in order" do
    values = User.theme_options.map { |option| option[:value] }

    assert_equal %w[
      standard
      neon
      catppuccin_mocha
      catppuccin_iced_latte
      gruvbox_dark
      github_dark
      github_light
      nord
      rose
      rose_pine_dawn
    ], values
  end

  test "theme metadata falls back to default for unknown themes" do
    metadata = User.theme_metadata("not-a-real-theme")

    assert_equal "gruvbox_dark", metadata[:value]
  end

  test "updating slack status does nothing without a slack access token" do
    user = User.create!(timezone: "UTC", uses_slack_status: true)

    user.update_slack_status

    assert_not_requested :get, "https://slack.com/api/users.profile.get"
    assert_not_requested :post, "https://slack.com/api/users.profile.set"
  end
end
