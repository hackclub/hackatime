require "test_helper"

class HeartbeatDeliveryJobTest < ActiveJob::TestCase
  test "serializes repairs per user without blocking unrelated users" do
    assert_equal "HeartbeatDeliveryJob:42", HeartbeatDeliveryJob.new(42).good_job_concurrency_key
    assert_equal "HeartbeatDeliveryJob:43", HeartbeatDeliveryJob.new(43).good_job_concurrency_key
    assert_equal "HeartbeatDeliveryJob:global", HeartbeatDeliveryJob.new.good_job_concurrency_key
  end
end
