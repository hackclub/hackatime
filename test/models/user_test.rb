require "test_helper"
require "webmock/minitest"

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

  test "update_slack_status skips blank current projects" do
    user = User.create!(
      timezone: "UTC",
      slack_uid: "U123",
      slack_access_token: "token",
      uses_slack_status: true
    )

    Heartbeat.create!(
      user: user,
      time: 10.minutes.ago.to_f,
      category: "coding",
      project: "hackatime",
      source_type: :test_entry
    )
    Heartbeat.create!(
      user: user,
      time: 1.minute.ago.to_f,
      category: "coding",
      project: nil,
      source_type: :test_entry
    )

    stub_request(:get, "https://slack.com/api/users.profile.get")
      .to_return(
        status: 200,
        body: { profile: { status_text: "" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    stub_request(:post, "https://slack.com/api/users.profile.set")
      .to_return(
        status: 200,
        body: { ok: true }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    user.update_slack_status

    assert_requested :get, "https://slack.com/api/users.profile.get", times: 1
    assert_not_requested :post, "https://slack.com/api/users.profile.set"
  end
end
