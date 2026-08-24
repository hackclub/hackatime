require "application_system_test_case"

class HeartbeatExportTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @user = create(:user, :with_email)
    sign_in_as(@user)
  end

  test "clicking export all heartbeats enqueues job and shows notice" do
    visit my_settings_imports_exports_path

    assert_enqueued_with(job: HeartbeatExportJob, args: [ @user.id, { all_data: true } ]) do
      click_on "Export all heartbeats"
      assert_text "Your export is being prepared and will be emailed to you"
    end
  end

  test "submitting export date range enqueues job and shows notice" do
    visit my_settings_imports_exports_path

    start_date = 7.days.ago.to_date.iso8601
    end_date = Date.current.iso8601
    fill_in "start_date", with: start_date
    fill_in "end_date", with: end_date

    assert_enqueued_with(
      job: HeartbeatExportJob,
      args: [ @user.id, { all_data: false, start_date: start_date, end_date: end_date } ]
    ) do
      click_on "Export date range"
      assert_text "Your export is being prepared and will be emailed to you"
    end
  end

  test "export request is rejected when signed-in user has no email address" do
    user_without_email = create(:user, :with_email)

    sign_in_as(user_without_email)
    user_without_email.email_addresses.destroy_all
    visit my_settings_imports_exports_path

    assert_no_enqueued_jobs only: HeartbeatExportJob do
      click_on "Export all heartbeats"
      assert_text "You need an email address on your account to export heartbeats."
    end
  end

  private

  def queue_adapter_for_test
    ActiveJob::QueueAdapters::TestAdapter.new
  end
end
