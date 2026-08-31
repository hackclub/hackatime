require "test_helper"

class My::HeartbeatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear
    GoodJob::Job.delete_all
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "export rejects banned users" do
    user = create(:user, :with_email, email: "banned-export@example.com", trust_level: :red)
    sign_in_as(user)

    post export_my_heartbeats_path, params: { all_data: "true" }

    assert_response :redirect
    assert_redirected_to my_settings_path
    assert_equal "Sorry, you are not permitted to this action.", flash[:alert]
  end

  test "export rejects invalid start date format" do
    user = create(:user, :with_email, email: "invalid-start-date@example.com")
    sign_in_as(user)

    post export_my_heartbeats_path, params: {
      all_data: "false",
      start_date: "not-a-date",
      end_date: Date.current.iso8601
    }

    assert_response :redirect
    assert_redirected_to my_settings_imports_exports_path
    assert_equal "Invalid date format. Please use YYYY-MM-DD.", flash[:alert]
  end

  test "export rejects start date after end date" do
    user = create(:user, :with_email, email: "invalid-range@example.com")
    sign_in_as(user)

    post export_my_heartbeats_path, params: {
      all_data: "false",
      start_date: Date.current.iso8601,
      end_date: 1.day.ago.to_date.iso8601
    }

    assert_response :redirect
    assert_redirected_to my_settings_imports_exports_path
    assert_equal "Start date must be on or before end date.", flash[:alert]
  end

  test "export rate limits repeated requests" do
    user = create(:user, :with_email, email: "rate-limited-export@example.com")
    sign_in_as(user)

    assert_difference -> { GoodJob::Job.where(job_class: "HeartbeatExportJob").count }, +1 do
      post export_my_heartbeats_path, params: { all_data: "true" }
    end

    assert_no_difference -> { GoodJob::Job.where(job_class: "HeartbeatExportJob").count } do
      post export_my_heartbeats_path, params: { all_data: "true" }
    end

    assert_response :redirect
    assert_redirected_to my_settings_imports_exports_path
    assert_equal "Export requests are limited to once every 10 minutes.", flash[:alert]
  end
    test "POST export enqueues job with include_stats when checked" do
    assert_enqueued_with(
      job: HeartbeatExportJob,
      args: [@user.id, hash_including(include_stats: true, all_data: true)]
    ) do
      post export_my_heartbeats_url, params: { all_data: "1", include_stats: "1" }
    end
  end
end
