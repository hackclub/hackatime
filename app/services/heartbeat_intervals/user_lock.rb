require "monitor"

module HeartbeatIntervals
  class UserLock
    LOCK_NAMESPACE = 0x4842
    LOCAL_LOCKS = Array.new(256) { Monitor.new }.freeze

    def self.call(user_ids:, &block)
      new(user_ids).call(&block)
    end

    def initialize(user_ids)
      user_ids = Array(user_ids).map(&:to_i).uniq.sort
      stripe_indexes = user_ids.map { |user_id| user_id % LOCAL_LOCKS.length }.uniq.sort
      @local_locks = stripe_indexes.map { |index| LOCAL_LOCKS.fetch(index) }
      @lock_keys = user_ids.map do |user_id|
        (LOCK_NAMESPACE << 32) | (user_id & 0xffff_ffff)
      end
    end

    def call(&block)
      with_local_locks(0, &block)
    end

    private

    attr_reader :local_locks, :lock_keys

    def with_local_locks(index, &block)
      return with_advisory_locks(&block) if index == local_locks.length

      local_locks.fetch(index).synchronize { with_local_locks(index + 1, &block) }
    end

    def with_advisory_locks
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        acquired_keys = []
        lock_keys.each do |key|
          connection.execute(ActiveRecord::Base.sanitize_sql([ "SELECT pg_advisory_lock(?)", key ]))
          acquired_keys << key
        end
        yield
      ensure
        acquired_keys&.reverse_each do |key|
          connection.execute(ActiveRecord::Base.sanitize_sql([ "SELECT pg_advisory_unlock(?)", key ]))
        end
      end
    end
  end
end
