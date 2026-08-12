require "test_helper"

class DashboardRollupRefreshJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @original_cache = Rails.cache
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
  end

  teardown do
    clear_enqueued_jobs
    Rails.cache = @original_cache
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "mutation during refresh schedules another refresh" do
    user = User.create!(timezone: "UTC")
    DashboardRollup.mark_dirty(user.id)
    Rails.cache.write(DashboardRollupRefreshJob.enqueue_cache_key(user.id), true)
    refresher = Object.new
    refresher.define_singleton_method(:call) { DashboardRollup.mark_dirty(user.id) }

    with_refresher(refresher) do
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        DashboardRollupRefreshJob.perform_now(user.id)
      end
    end

    assert DashboardRollup.dirty?(user.id)
  end

  test "failed refresh remains dirty and schedules another refresh" do
    user = User.create!(timezone: "UTC")
    DashboardRollup.mark_dirty(user.id)
    Rails.cache.write(DashboardRollupRefreshJob.enqueue_cache_key(user.id), true)
    refresher = Object.new
    refresher.define_singleton_method(:call) { raise "refresh failed" }

    with_refresher(refresher) do
      assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
        assert_raises(RuntimeError) { DashboardRollupRefreshJob.perform_now(user.id) }
      end
    end

    assert DashboardRollup.dirty?(user.id)
  end

  test "successful refresh clears dirty state without another refresh" do
    user = User.create!(timezone: "UTC")
    DashboardRollup.mark_dirty(user.id)
    Rails.cache.write(DashboardRollupRefreshJob.enqueue_cache_key(user.id), true)
    refresher = Object.new
    refresher.define_singleton_method(:call) { nil }

    with_refresher(refresher) do
      assert_no_enqueued_jobs(only: DashboardRollupRefreshJob) do
        DashboardRollupRefreshJob.perform_now(user.id)
      end
    end

    assert_not DashboardRollup.dirty?(user.id)
  end

  test "cache eviction does not lose dirty refresh state" do
    user = User.create!(timezone: "UTC")
    DashboardRollupRefreshJob.schedule_for(user.id)
    clear_enqueued_jobs
    Rails.cache.clear

    assert DashboardRollup.dirty?(user.id)
    assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ user.id ]) do
      DashboardRollupRefreshJob.perform_now
    end
  end

  private

  def with_refresher(refresher)
    original = DashboardRollupRefreshService.method(:new)
    DashboardRollupRefreshService.define_singleton_method(:new) { |**| refresher }
    yield
  ensure
    DashboardRollupRefreshService.define_singleton_method(:new, original)
  end
end
