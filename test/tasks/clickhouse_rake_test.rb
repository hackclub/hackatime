require "test_helper"
require "rake"

class ClickhouseRakeTest < ActiveJob::TestCase
  TASK_NAME = "clickhouse:enqueue_serving_backfill"

  Rails.application.load_tasks unless Rake::Task.task_defined?(TASK_NAME)

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :good_job
    @original_batch_size = ENV["BATCH_SIZE"]
    @original_start_after = ENV["START_AFTER"]
    @created_job_ids = []
    @existing_rebuild_job_ids = GoodJob::Job.where(job_class: "HeartbeatServingRebuildJob").pluck(:active_job_id)
  end

  teardown do
    GoodJob::Job.where(active_job_id: @created_job_ids).delete_all
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    ENV["BATCH_SIZE"] = @original_batch_size
    ENV["START_AFTER"] = @original_start_after
  end

  test "persists every batch and reports truthful progress" do
    user_ids = Array.new(5) { create_user_with_heartbeat.id }.sort
    ENV["BATCH_SIZE"] = "2"
    ENV.delete("START_AFTER")

    output, = capture_io { task.invoke }
    jobs = new_rebuild_jobs

    assert_equal 3, jobs.size
    assert_equal user_ids.each_slice(2).to_a, jobs.map { |job| job.serialized_params.fetch("arguments").first }
    assert_match(/Enqueued 3 batches for 5 users\./, output)
    assert_match(/user_id=#{user_ids.last}/, output)
  end

  test "does not advance the cursor when a batch is rejected" do
    user_ids = Array.new(3) { create_user_with_heartbeat.id }.sort
    ENV["BATCH_SIZE"] = "2"
    ENV.delete("START_AFTER")
    rejected_job = HeartbeatServingRebuildJob.new
    rejected_job.successfully_enqueued = false
    rejected_job.enqueue_error = ActiveJob::EnqueueError.new("queue unavailable")

    output, error_output = capture_io do
      error = assert_raises(ActiveJob::EnqueueError) do
        with_rejected_enqueue(rejected_job) { task.invoke }
      end
      assert_equal "queue unavailable", error.message
    end

    assert_empty output
    assert_match(/users #{user_ids.first}, #{user_ids.second}/, error_output)
    assert_match(/START_AFTER=0/, error_output)
    assert_no_match(/Enqueued 2 users/, output)
  end

  private

  def task
    Rake::Task[TASK_NAME].tap(&:reenable)
  end

  def create_user_with_heartbeat
    User.create!(timezone: "UTC").tap do |user|
      create_heartbeat(user: user, time: Time.utc(2026, 7, 10, 12).to_f, source_type: :test_entry)
    end
  end

  def new_rebuild_jobs
    jobs = GoodJob::Job.where(job_class: "HeartbeatServingRebuildJob")
      .where.not(active_job_id: @existing_rebuild_job_ids)
      .order(:created_at, :id)
      .to_a
    @created_job_ids.concat(jobs.map(&:active_job_id))
    jobs
  end

  def with_rejected_enqueue(rejected_job)
    singleton_class = HeartbeatServingRebuildJob.singleton_class
    original_method = HeartbeatServingRebuildJob.method(:perform_later)
    singleton_class.define_method(:perform_later) { |*, **| rejected_job }
    yield
  ensure
    singleton_class&.define_method(:perform_later, original_method) if original_method
  end
end
