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

  test "rotate_api_keys! replaces existing api key with a new one" do
    user = User.create!(timezone: "UTC", slack_uid: "U#{SecureRandom.hex(8)}")
    user.api_keys.create!(name: "Original key")
    original_token = user.api_keys.first.token

    new_api_key = user.rotate_api_keys!

    assert_equal user.id, new_api_key.user_id
    assert_equal "Hackatime key", new_api_key.name
    assert_nil ApiKey.find_by(token: original_token)
  end

  test "rotate_api_keys! creates a key when none exists" do
    user = User.create!(timezone: "UTC", slack_uid: "U#{SecureRandom.hex(8)}")

    assert_equal 0, user.api_keys.count

    new_api_key = user.rotate_api_keys!

    assert_equal user.id, new_api_key.user_id
    assert_equal "Hackatime key", new_api_key.name
    assert_equal [ new_api_key.id ], user.api_keys.reload.pluck(:id)
  end

  test "flipper id uses the user id" do
    user = User.create!(timezone: "UTC")

    assert_equal "User;#{user.id}", user.flipper_id
  end

  test "active remote heartbeat import run only counts remote imports" do
    user = User.create!(timezone: "UTC")

    assert_not user.active_remote_heartbeat_import_run?

    # An active non-remote (dev_upload) import should not count as a remote import.
    # Use a separate user because the unique index prevents two active imports per user.
    other_user = User.create!(timezone: "UTC")
    other_user.heartbeat_import_runs.create!(
      source_kind: :dev_upload,
      state: :queued,
      source_filename: "dev.json"
    )
    assert_not other_user.active_remote_heartbeat_import_run?

    user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret"
    )

    assert user.active_remote_heartbeat_import_run?
  end
end
