class HeartbeatImportService
  BATCH_SIZE = 50_000

  def self.import_from_file(file_content, user, on_progress: nil, progress_interval: 250, user_agents_by_id: {})
    imported_count = 0
    total_count = 0
    errors = []
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    heartbeat_batch = []

    flush = lambda do
      next if heartbeat_batch.empty?
      result = HeartbeatIngest.call(user:, mode: :import, heartbeats: heartbeat_batch,
                                    user_agents_by_id:, schedule_rollup_refresh: false)
      imported_count += result.persisted_count
      errors.concat(result.errors)
      heartbeat_batch.clear
    end

    handler = HeartbeatStreamHandler.new do |hb|
      total_count += 1
      on_progress&.call(total_count) if progress_interval.positive? && (total_count % progress_interval).zero?

      heartbeat_batch << hb
      flush.call if heartbeat_batch.size >= BATCH_SIZE
    end

    Oj.sc_parse(handler, file_content)
    on_progress&.call(total_count)

    raise StandardError, "Expected a heartbeat export JSON file." if total_count.zero?
    flush.call
    HeartbeatIngest.schedule_rollup_refresh(user:) if imported_count.positive?

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    { success: true, imported_count:, total_count:,
      skipped_count: total_count - imported_count, errors:, time_taken: elapsed.round(2) }
  rescue => e
    { success: false, error: e.message, imported_count:, total_count:,
      skipped_count: total_count - imported_count, errors: errors + [ e.message ] }
  end

  # Retain only the current heartbeat, not the surrounding dump or day arrays.
  # Unlike SAJ, ScHandler preserves embedded NULs for ingestion to sanitize.
  class HeartbeatStreamHandler < Oj::ScHandler
    def initialize(&block)
      @block = block
      @depth = 0
      @heartbeat_array_depths = []
    end

    def hash_start
      @key = nil
      @depth += 1
      {} if @heartbeat_array_depths.any?
    end

    def hash_end
      @depth -= 1
    end

    def hash_key(key)
      @key = key
    end

    def hash_set(hash, key, value)
      hash[key] = value if hash
    end

    def array_start
      container = if @key == "heartbeats" && @heartbeat_array_depths.empty?
        @heartbeat_array_depths << @depth
        :heartbeats
      elsif @heartbeat_array_depths.any?
        []
      end
      @key = nil
      @depth += 1
      container
    end

    def array_end
      @depth -= 1
      @heartbeat_array_depths.pop if @heartbeat_array_depths.last == @depth
    end

    def array_append(array, value)
      if array == :heartbeats
        @block.call(value)
      elsif array
        array << value
      end
    end
  end
end
