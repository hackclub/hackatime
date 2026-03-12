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

  test "flipper id uses the user id" do
    user = User.create!(timezone: "UTC")

    assert_equal "User;#{user.id}", user.flipper_id
  end

  test "active remote heartbeat import run only counts remote imports" do
    user = User.create!(timezone: "UTC")

    assert_not user.active_remote_heartbeat_import_run?

    user.heartbeat_import_runs.create!(
      source_kind: :dev_upload,
      state: :queued,
      source_filename: "dev.json"
    )

    assert_not user.active_remote_heartbeat_import_run?

    user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :waiting_for_dump,
      encrypted_api_key: "secret"
    )

    assert user.active_remote_heartbeat_import_run?
  end
end
