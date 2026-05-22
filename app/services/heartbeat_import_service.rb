class HeartbeatImportService
  BATCH_SIZE = 50_000

  def self.import_from_file(file_content, user, on_progress: nil, progress_interval: 250, user_agents_by_id: {})
    imported_count = 0
    total_count = 0
    errors = []
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    heartbeat_batch = {}

    flush = lambda do
      next if heartbeat_batch.empty?
      result = HeartbeatIngest.call(user:, mode: :import, heartbeats: heartbeat_batch.values,
                                    user_agents_by_id:, schedule_rollup_refresh: false)
      imported_count += result.persisted_count
      errors.concat(result.errors)
      heartbeat_batch.clear
    end

    handler = HeartbeatSaxHandler.new do |hb|
      total_count += 1
      on_progress&.call(total_count) if progress_interval.positive? && (total_count % progress_interval).zero?

      begin
        attrs = HeartbeatIngest.normalize_imported_heartbeat(user:, heartbeat: hb, user_agents_by_id:)
        heartbeat_batch[attrs[:fields_hash]] = hb
        flush.call if heartbeat_batch.size >= BATCH_SIZE
      rescue => e
        errors << { heartbeat: hb, error: e.message }
      end
    end

    Oj.saj_parse(handler, file_content)
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

  def self.count_heartbeats(file_content)
    total_count = 0
    Oj.saj_parse(HeartbeatSaxHandler.new { |_hb| total_count += 1 }, file_content)
    total_count
  end

  class HeartbeatSaxHandler < Oj::Saj
    def initialize(&block)
      @block = block
      @depth = 0
      @current_heartbeat = nil
      @heartbeat_array_depths = []
      @field_array_stack = []
    end

    def hash_start(key)
      @current_heartbeat = {} if inside_heartbeat_array? && @depth == @heartbeat_array_depths.last + 1
      @depth += 1
    end

    def hash_end(key)
      @depth -= 1
      if inside_heartbeat_array? && @depth == @heartbeat_array_depths.last + 1 && @current_heartbeat
        @block.call(@current_heartbeat)
        @current_heartbeat = nil
      end
    end

    def array_start(key)
      @heartbeat_array_depths << @depth if key == "heartbeats"
      if @current_heartbeat && key.present?
        @current_heartbeat[key] = []
        @field_array_stack << key
      end
      @depth += 1
    end

    def array_end(key)
      @depth -= 1
      @heartbeat_array_depths.pop if key == "heartbeats" && @heartbeat_array_depths.last == @depth
      @field_array_stack.pop if @field_array_stack.last == key
    end

    def add_value(value, key)
      return unless @current_heartbeat
      if key
        @current_heartbeat[key] = value
      elsif @field_array_stack.any?
        @current_heartbeat[@field_array_stack.last] << value
      end
    end

    private

    def inside_heartbeat_array? = @heartbeat_array_depths.any?
  end
end
