require "test_helper"
require "zip"

class HeartbeatExportJobTest < ActiveJob::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
    GoodJob::Job.delete_all
    @user = User.create!(
      timezone: "UTC",
      slack_uid: "U#{SecureRandom.hex(5)}",
      username: "job_export_#{SecureRandom.hex(4)}"
    )
    @user.email_addresses.create!(
      email: "job-export-#{SecureRandom.hex(6)}@example.com",
      source: :signing_in
    )
  end

  test "all-data export uploads blob, schedules cleanup, and emails download link" do
    first_time = Time.utc(2026, 2, 10, 12, 0, 0)
    second_time = Time.utc(2026, 2, 12, 12, 0, 0)

    hb1 = create_heartbeat(at_time: first_time, entity: "src/first.rb")
    hb2 = create_heartbeat(at_time: second_time, entity: "src/second.rb")

    assert_difference -> { ActiveStorage::Blob.count }, 1 do
      assert_difference -> { GoodJob::Job.where(job_class: "HeartbeatExportCleanupJob").count }, 1 do
        HeartbeatExportJob.perform_now(@user.id, all_data: true)
      end
    end

    assert_equal 1, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ @user.email_addresses.first.email ], mail.to
    assert_equal "Your Hackatime heartbeat export is ready", mail.subject

    blob = ActiveStorage::Blob.order(created_at: :asc).last
    assert_equal "application/zip", blob.content_type
    assert_match(/\Aheartbeats_#{@user.slack_uid}_20260210_20260212\.zip\z/, blob.filename.to_s)

    payload = parse_zipped_export_payload(
      blob.download,
      "heartbeats_#{@user.slack_uid}_20260210_20260212.json"
    )
    assert_equal "2026-02-10", payload.dig("export_info", "date_range", "start_date")
    assert_equal "2026-02-12", payload.dig("export_info", "date_range", "end_date")
    assert_equal 2, payload.dig("export_info", "total_heartbeats")
    assert_equal @user.heartbeats.order(time: :asc).duration_seconds, payload.dig("export_info", "total_duration_seconds")
    assert_equal [ hb1.id, hb2.id ], payload.fetch("heartbeats").map { |row| row.fetch("id") }
    assert_equal "src/first.rb", payload.fetch("heartbeats").first.fetch("entity")
    assert_equal "src/second.rb", payload.fetch("heartbeats").last.fetch("entity")

    assert_includes mail.text_part.body.decoded, "/rails/active_storage/blobs/proxy/"
  end

  test "date-range export includes only heartbeats in range" do
    out_of_range = create_heartbeat(at_time: Time.utc(2026, 2, 9, 23, 59, 59), entity: "src/out.rb")
    in_range_one = create_heartbeat(at_time: Time.utc(2026, 2, 10, 9, 0, 0), entity: "src/in_one.rb")
    in_range_two = create_heartbeat(at_time: Time.utc(2026, 2, 11, 23, 59, 59), entity: "src/in_two.rb")

    HeartbeatExportJob.perform_now(
      @user.id,
      all_data: false,
      start_date: "2026-02-10",
      end_date: "2026-02-11"
    )

    payload = parse_zipped_export_payload(
      ActiveStorage::Blob.order(created_at: :asc).last.download,
      "heartbeats_#{@user.slack_uid}_20260210_20260211.json"
    )
    exported_ids = payload.fetch("heartbeats").map { |row| row.fetch("id") }

    assert_equal [ in_range_one.id, in_range_two.id ], exported_ids
    assert_not_includes exported_ids, out_of_range.id
    assert_equal "2026-02-10", payload.dig("export_info", "date_range", "start_date")
    assert_equal "2026-02-11", payload.dig("export_info", "date_range", "end_date")
  end

  test "job returns without email and does not send a message" do
    user_without_email = User.create!(
      timezone: "UTC",
      slack_uid: "U#{SecureRandom.hex(5)}",
      username: "job_no_email_#{SecureRandom.hex(4)}"
    )
    user_without_email.heartbeats.create!(
      entity: "src/no_email.rb",
      type: "file",
      category: "coding",
      time: Time.current.to_f,
      project: "export-test",
      source_type: :test_entry
    )

    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      HeartbeatExportJob.perform_now(user_without_email.id, all_data: true)
    end
  end

  test "job returns silently when user is missing" do
    missing_user_id = User.maximum(:id).to_i + 1000

    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      HeartbeatExportJob.perform_now(missing_user_id, all_data: true)
    end
  end

  test "invalid date arguments do not send email" do
    create_heartbeat(at_time: Time.utc(2026, 2, 10, 12, 0, 0), entity: "src/valid.rb")

    assert_no_difference -> { ActionMailer::Base.deliveries.count } do
      HeartbeatExportJob.perform_now(
        @user.id,
        all_data: false,
        start_date: "not-a-date",
        end_date: "2026-02-11"
      )
    end
  end

  private

  def create_heartbeat(at_time:, entity:)
    @user.heartbeats.create!(
      entity: entity,
      type: "file",
      category: "coding",
      time: at_time.to_f,
      project: "export-test",
      source_type: :test_entry
    )
  end

  def parse_zipped_export_payload(zip_bytes, json_filename)
    zip_data = zip_bytes
    zip_data = zip_data.download if zip_data.respond_to?(:download)

    if zip_data.respond_to?(:read)
      zip_data.rewind if zip_data.respond_to?(:rewind)
      zip_data = zip_data.read
    end

    payload = nil
    found_expected_entry = false

    Zip::InputStream.open(StringIO.new(zip_data.to_s)) do |stream|
      while (entry = stream.get_next_entry)
        next unless entry.name.end_with?(".json")

        payload = JSON.parse(stream.read)
        found_expected_entry = entry.name == json_filename
        break if found_expected_entry
      end
    end

    assert_not_nil payload, "Expected zip to include a JSON file"
    assert found_expected_entry, "Expected zip to include #{json_filename}"
    payload
  end
end
