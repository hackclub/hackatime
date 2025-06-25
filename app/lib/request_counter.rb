class RequestCounter
  WINDOW_SIZE = 10 # seconds - shorter window for more responsive rates
  HIGH_LOAD_THRESHOLD = 500 # req/sec to disable tracking
  CIRCUIT_BREAKER_DURATION = 30 # seconds to stay disabled

  @buckets = {}
  @disabled_until = nil

  class << self
    def increment
      return if disabled?

      current_time = Time.current.to_i
      @buckets[current_time] = (@buckets[current_time] || 0) + 1

      # Check if we should disable due to high load
      check_circuit_breaker(current_time)

      # Periodically clean old buckets (1% chance)
      cleanup if rand(100) == 0
    end

    def per_second
      return :high_load if disabled?

      current_time = Time.current.to_i
      cutoff = current_time - WINDOW_SIZE

      total = @buckets.select { |timestamp, _| timestamp >= cutoff }.values.sum
      (total.to_f / WINDOW_SIZE).round(2)
    end

    private

    def disabled?
      @disabled_until && Time.current.to_i < @disabled_until
    end

    def check_circuit_breaker(current_time)
      # Check last 5 seconds for high load
      recent_total = @buckets.select { |ts, _| ts >= current_time - 5 }.values.sum

      if recent_total > HIGH_LOAD_THRESHOLD * 5 # 5 seconds worth
        @disabled_until = current_time + CIRCUIT_BREAKER_DURATION
        @buckets.clear # Clear to reduce memory
      end
    end

    def cleanup
      return if disabled? # Skip cleanup when disabled

      current_time = Time.current.to_i
      cutoff = current_time - WINDOW_SIZE - 10 # extra buffer
      @buckets.reject! { |timestamp, _| timestamp < cutoff }
    end
  end
end
