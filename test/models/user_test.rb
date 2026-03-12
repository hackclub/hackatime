require "test_helper"

class UserTest < ActiveSupport::TestCase
  fixtures :users, :api_keys

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

  test "rotate_api_key! replaces existing api keys with a new one" do
    user = users(:one)
    original_token = user.api_keys.first.token
    user.api_keys.create!(name: "Secondary key")

    new_api_key = user.rotate_api_key!

    assert_equal user.id, new_api_key.user_id
    assert_equal "Hackatime key", new_api_key.name
    assert_equal [ new_api_key.id ], user.api_keys.reload.pluck(:id)
    assert_nil ApiKey.find_by(token: original_token)
  end

  test "rotate_api_key! creates a key when none exists" do
    user = users(:three)

    assert_equal 0, user.api_keys.count

    new_api_key = user.rotate_api_key!

    assert_equal user.id, new_api_key.user_id
    assert_equal "Hackatime key", new_api_key.name
    assert_equal [ new_api_key.id ], user.api_keys.reload.pluck(:id)
  end
end
