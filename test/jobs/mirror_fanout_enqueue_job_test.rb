require "test_helper"

class MirrorFanoutEnqueueJobTest < ActiveJob::TestCase
  setup do
    Flipper.enable(:wakatime_imports_mirrors)
  end

  teardown do
    Flipper.disable(:wakatime_imports_mirrors)
  end

  test "debounce prevents enqueue storms per user" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    GoodJob::Job.delete_all
    user = User.create!(timezone: "UTC")
    user.wakatime_mirrors.create!(
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "mirror-key-1"
    )
    user.wakatime_mirrors.create!(
      endpoint_url: "https://wakapi.dev/api/compat/wakatime/v1",
      encrypted_api_key: "mirror-key-2"
    )

    assert_difference -> { GoodJob::Job.where(job_class: "WakatimeMirrorSyncJob").count }, 2 do
      MirrorFanoutEnqueueJob.perform_now(user.id)
      MirrorFanoutEnqueueJob.perform_now(user.id)
    end
  ensure
    Rails.cache = original_cache
  end

  test "does not enqueue mirror sync when imports and mirrors are disabled" do
    GoodJob::Job.delete_all
    user = User.create!(timezone: "UTC")
    user.wakatime_mirrors.create!(
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "mirror-key"
    )
    Flipper.disable(:wakatime_imports_mirrors)

    assert_no_difference -> { GoodJob::Job.where(job_class: "WakatimeMirrorSyncJob").count } do
      MirrorFanoutEnqueueJob.perform_now(user.id)
    end
  end
end
