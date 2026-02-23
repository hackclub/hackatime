require "test_helper"

class MirrorFanoutEnqueueJobTest < ActiveJob::TestCase
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
end
