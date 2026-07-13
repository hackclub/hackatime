require "test_helper"

class HeartbeatIntervals::UserLockTest < ActiveSupport::TestCase
  test "orders striped locks independently of wrapped user id order" do
    lock = HeartbeatIntervals::UserLock.new([ 256, 1 ])
    local_locks = lock.send(:local_locks)
    stripe_indexes = local_locks.map { |local_lock| HeartbeatIntervals::UserLock::LOCAL_LOCKS.index(local_lock) }

    assert_equal [ 0, 1 ], stripe_indexes
  end
end
