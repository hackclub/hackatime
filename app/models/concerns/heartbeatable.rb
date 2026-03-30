module Heartbeatable
  extend ActiveSupport::Concern

  included do
    # Filter heartbeats to only include those with category equal to "coding"
    scope :coding_only, -> { where(category: "coding") }

    # This is to prevent PG timestamp overflow errors if someones gives us a
    # heartbeat with a time that is enormously far in the future.
    scope :with_valid_timestamps, -> { where("time >= 0 AND time <= ?", 253402300799) }
  end

  class_methods do
    def heartbeat_timeout_duration(duration = nil)
      if duration
        @heartbeat_timeout_duration = duration
      else
        @heartbeat_timeout_duration || 2.minutes
      end
    end
  end
end
