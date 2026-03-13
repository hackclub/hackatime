require "test_helper"

class HeartbeatImportRunTest < ActiveSupport::TestCase
  test "requires api key for remote imports on create" do
    run = HeartbeatImportRun.new(
      user: User.create!(timezone: "UTC"),
      source_kind: :wakatime_dump,
      state: :queued
    )

    assert_not run.valid?
    assert_includes run.errors[:encrypted_api_key], "can't be blank"
  end

  test "does not require api key for wakatime download link imports" do
    run = HeartbeatImportRun.new(
      user: User.create!(timezone: "UTC"),
      source_kind: :wakatime_download_link,
      state: :queued
    )

    assert run.valid?
    assert_not run.remote?
    assert run.wakatime?
  end

  test "remote cooldown helper returns future timestamp for recent remote import" do
    user = User.create!(timezone: "UTC")
    run = user.heartbeat_import_runs.create!(
      source_kind: :wakatime_dump,
      state: :completed,
      encrypted_api_key: "secret",
      remote_requested_at: 2.minutes.ago
    )

    cooldown_until = HeartbeatImportRun.remote_cooldown_until_for(user)

    assert_in_delta run.remote_requested_at + 8.minutes, cooldown_until, 1.second
  end

  test "active_for returns the latest active import" do
    user = User.create!(timezone: "UTC")
    user.heartbeat_import_runs.create!(
      source_kind: :dev_upload,
      state: :completed,
      source_filename: "old.json"
    )
    latest = user.heartbeat_import_runs.create!(
      source_kind: :dev_upload,
      state: :queued,
      source_filename: "new.json"
    )

    assert_equal latest, HeartbeatImportRun.active_for(user)
  end
end
