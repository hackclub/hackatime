require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "theme defaults to standard" do
    user = User.create!

    assert_equal "standard", user.theme
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
    ], values
  end

  test "theme metadata falls back to standard for unknown themes" do
    metadata = User.theme_metadata("not-a-real-theme")

    assert_equal "standard", metadata[:value]
  end
end
