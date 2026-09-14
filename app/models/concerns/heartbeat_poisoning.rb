module HeartbeatPoisoning
  extend ActiveSupport::Concern

  THREAD_KEY = :hackatime_include_poisoned_heartbeats

  included do
    def self.poisoned_arel
      users = User.arel_table
      heartbeats = arel_table
      cutoff_epoch = Arel::Nodes::NamedFunction.new(
        "EXTRACT", [ Arel::Nodes::InfixOperation.new("FROM", Arel.sql("EPOCH"), users[:poisoned_until]) ]
      )

      users.project(1)
           .where(users[:id].eq(heartbeats[:user_id]))
           .where(users[:poisoned_until].not_eq(nil))
           .where(heartbeats[:time].lt(cutoff_epoch))
           .exists
    end

    default_scope { HeartbeatPoisoning.included_poison? ? all : where.not(poisoned_arel) }

    scope :excluding_poisoned, -> { where.not(poisoned_arel) }

    scope :only_poisoned, -> { unscoped.where(deleted_at: nil).where(poisoned_arel) }
  end

  class_methods do
    def including_poison(&block) = HeartbeatPoisoning.including_poison(&block)
  end

  def self.included_poison? = Thread.current[THREAD_KEY].present?

  def self.including_poison
    previous = Thread.current[THREAD_KEY]
    Thread.current[THREAD_KEY] = true
    yield
  ensure
    Thread.current[THREAD_KEY] = previous
  end
end
