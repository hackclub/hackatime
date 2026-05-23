class RequestCounter
  WINDOW_SIZE = 10 # seconds
  HIGH_LOAD_THRESHOLD = 500 # req/sec to disable
  CIRCUIT_BREAKER_DURATION = 30 # seconds
  PROCESS_ID = "#{Socket.gethostname}-#{Process.pid}"
  STATS_DIR = Rails.root.join("tmp", "request_stats")

  @buckets = {}
  @disabled_until = nil
  @last_sync = 0

  class << self
    def increment
      return if disabled?
      now = Time.current.to_i
      @buckets[now] = (@buckets[now] || 0) + 1
      check_circuit_breaker(now)
      if rand(100) == 0
        sync_to_file(now)
        cleanup
      end
    end

    def per_second
      return :high_load if disabled?
      cutoff = Time.current.to_i - WINDOW_SIZE
      local_total = @buckets.select { |ts, _| ts >= cutoff }.values.sum
      (local_total.to_f / WINDOW_SIZE).round(2)
    end

    def global_per_second
      return :high_load if disabled?
      now = Time.current.to_i
      sync_to_file(now)
      cutoff = now - WINDOW_SIZE
      total = 0

      Dir.glob(STATS_DIR.join("*.txt")).each do |file_path|
        next unless File.mtime(file_path) > (cutoff - 60).seconds.ago
        begin
          File.read(file_path).each_line do |line|
            next if line.strip.empty?
            ts, count = line.strip.split(":", 2)
            total += count.to_i if ts && count && ts.to_i >= cutoff
          end
        rescue Errno::ENOENT
        end
      end

      (total.to_f / WINDOW_SIZE).round(2)
    end

    private

    def disabled? = @disabled_until && Time.current.to_i < @disabled_until

    def check_circuit_breaker(now)
      recent_total = @buckets.select { |ts, _| ts >= now - 5 }.values.sum
      return unless recent_total > HIGH_LOAD_THRESHOLD * 5
      @disabled_until = now + CIRCUIT_BREAKER_DURATION
      @buckets.clear
    end

    def sync_to_file(now)
      return if now == @last_sync || @buckets.empty?
      FileUtils.mkdir_p(STATS_DIR) unless Dir.exist?(STATS_DIR)
      file_path = STATS_DIR.join("#{PROCESS_ID}.txt")
      temp_path = "#{file_path}.tmp"
      File.write(temp_path, @buckets.map { |ts, count| "#{ts}:#{count}" }.join("\n"))
      File.rename(temp_path, file_path)
      @last_sync = now
    rescue Errno::ENOENT, Errno::EACCES
    end

    def cleanup
      cutoff = Time.current.to_i - WINDOW_SIZE - 10
      @buckets.reject! { |ts, _| ts < cutoff }
      return unless rand(10) == 0
      Dir.glob(STATS_DIR.join("*.txt")).each do |fp|
        File.delete(fp) if File.mtime(fp) < (cutoff - 60).seconds.ago
      rescue Errno::ENOENT
      end
    end
  end
end
