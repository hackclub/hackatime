require "test_helper"

# Runs without a wrapping transaction so each thread gets its own Postgres
# connection, which the per-user advisory lock needs to serialise requests.
class HeartbeatIngestConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    User.where(id: @user&.id).delete_all
  end

  test "concurrent identical direct ingests insert one heartbeat" do
    @user = create(:user)
    payload = { entity: "src/raced.rb", time: Time.current.to_f, type: "file" }
    start = Concurrent::CountDownLatch.new(1)

    threads = 4.times.map do
      Thread.new do
        start.wait
        ActiveRecord::Base.connection_pool.with_connection do
          HeartbeatIngest.call(user: @user, mode: :direct, heartbeats: [ payload ], schedule_rollup_refresh: false)
        end
      end
    end
    start.count_down
    results = threads.map(&:value)

    assert_equal 1, @user.heartbeats.count
    assert_equal 1, results.sum(&:persisted_count)
    assert_equal 3, results.sum(&:duplicate_count)
    assert_equal 1, results.map { |result| result.items.sole.heartbeat.id }.uniq.length
  end
end
