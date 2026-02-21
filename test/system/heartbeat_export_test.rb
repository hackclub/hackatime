require "application_system_test_case"

class HeartbeatExportTest < ApplicationSystemTestCase
  fixtures :users, :email_addresses, :heartbeats, :sign_in_tokens, :api_keys, :admin_api_keys

  setup do
    GoodJob::Job.delete_all
    @user = users(:one)
    sign_in_as(@user)
  end

  test "clicking export all heartbeats enqueues job and shows notice" do
    visit my_settings_data_path

    assert_text "Export all heartbeats"

    assert_difference -> { export_job_count }, 1 do
      click_on "Export all heartbeats"
      assert_text "Your export is being prepared and will be emailed to you"
    end

    assert_latest_export_job_kwargs(
      "all_data" => true
    )
  end

  test "submitting export date range enqueues job and shows notice" do
    visit my_settings_data_path

    start_date = 7.days.ago.to_date.iso8601
    end_date = Date.current.iso8601
    set_date_input("start_date", start_date)
    set_date_input("end_date", end_date)

    assert_difference -> { export_job_count }, 1 do
      click_on "Export date range"
      assert_text "Your export is being prepared and will be emailed to you"
    end

    assert_latest_export_job_kwargs(
      "all_data" => false,
      "start_date" => start_date,
      "end_date" => end_date
    )
  end

  test "export is not available for restricted users" do
    @user.update!(trust_level: :red)
    visit my_settings_data_path

    assert_text "Data export is currently restricted for this account."
  end

  test "export request is rejected when signed-in user has no email address" do
    user_without_email = users(:three)
    create_heartbeat(user_without_email, Time.current - 1.hour, "src/no_email.rb")

    sign_in_as(user_without_email)
    visit my_settings_data_path

    assert_difference -> { export_job_count }, 0 do
      click_on "Export all heartbeats"
      assert_text "You need an email address on your account to export heartbeats."
    end
  end

  private

  def export_job_count
    export_jobs.count
  end

  def export_jobs
    GoodJob::Job.where(job_class: "HeartbeatExportJob").order(created_at: :asc)
  end

  def latest_export_job
    export_jobs.last
  end

  def latest_export_job_kwargs
    serialized_params = latest_export_job.serialized_params
    args = serialized_params.fetch("arguments")
    kwargs = args.second || {}
    kwargs.except("_aj_ruby2_keywords")
  end

  def assert_latest_export_job_kwargs(expected_kwargs)
    assert_equal expected_kwargs, latest_export_job_kwargs
  end

  def create_heartbeat(user, at_time, entity)
    user.heartbeats.create!(
      entity: entity,
      type: "file",
      category: "coding",
      time: at_time.to_f,
      project: "export-test",
      source_type: :test_entry
    )
  end

  def set_date_input(field_name, value)
    execute_script(<<~JS, field_name, value)
      const input = document.querySelector(`input[name="${arguments[0]}"]`);
      input.value = arguments[1];
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end
end
