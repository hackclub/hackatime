require "test_helper"

class DashboardRollupConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include ActiveJob::TestHelper

  test "a correction during refresh leaves a coherent snapshot and a pending refresh" do
    original_cache = Rails.cache
    original_adapter = ActiveJob::Base.queue_adapter
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActiveJob::Base.queue_adapter = :test
    user = create(:user)
    create(:heartbeat, user: user, project: "api", language: "Ruby", time: 1_700_000_000.0)
    heartbeat = create(:heartbeat, user: user, project: "api", language: "Ruby", time: 1_700_000_060.0)
    DashboardRollupRefreshService.new(user: user).call
    clear_enqueued_jobs
    Rails.cache.clear
    DashboardRollupRefreshJob.schedule_for(user.id)
    main_thread = Thread.current
    corrected = false
    subscriber = lambda do |*args|
      payload = args.last
      if Thread.current == main_thread && !corrected && payload[:sql].include?('SELECT COUNT(*) FROM "heartbeats"')
        corrected = true
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Heartbeat.find(heartbeat.id).update!(language: "Python")
          end
        end.value
      end
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      DashboardRollupRefreshJob.perform_now(user.id)
    end

    assert corrected, "the concurrent correction must run during the aggregate reads"
    assert DashboardRollup.dirty?(user.id), "the newer invalidation must survive refresh completion"
    buckets = DashboardRollup.where(user: user, dimension: "language").to_h { |row| [ row.bucket, row.total_seconds ] }
    assert_equal({ "Ruby" => 60 }, buckets)
    assert_enqueued_jobs 2, only: DashboardRollupRefreshJob

    DashboardRollupRefreshJob.perform_now(user.id)
    assert_not DashboardRollup.dirty?(user.id)
    assert_equal 60, DashboardRollup.find_by!(user: user, dimension: "language", bucket_value: "Python").total_seconds
    DashboardRollup.mark_dirty(user.id)
    Rails.cache.clear
    assert DashboardRollup.dirty?(user.id), "invalidations must survive cache loss"
  ensure
    DashboardRollup.where(user: user).delete_all if user
    Heartbeat.with_deleted.where(user: user).delete_all if user
    user&.destroy!
    clear_enqueued_jobs
    Rails.cache = original_cache
    ActiveJob::Base.queue_adapter = original_adapter
  end
end
