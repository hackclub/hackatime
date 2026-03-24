class HeartbeatImportService
  BATCH_SIZE = 50_000

  def self.import_from_file(file_content, user, on_progress: nil, progress_interval: 250)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    user_id = user.id
    imported_count = 0
    total_count = 0
    errors = []
    seen_hashes = {}

    handler = HeartbeatSaxHandler.new do |hb|
      total_count += 1
      on_progress&.call(total_count) if progress_interval.positive? && (total_count % progress_interval).zero?

      begin
        time_value = hb["time"].is_a?(String) ? Time.parse(hb["time"]).to_f : hb["time"].to_f

        attrs = {
          user_id: user_id,
          time: time_value,
          entity: hb["entity"],
          type: hb["type"],
          category: hb["category"] || "coding",
          project: hb["project"],
          language: hb["language"],
          editor: hb["editor"],
          operating_system: hb["operating_system"],
          machine: hb["machine"] || hb["machine_name_id"],
          branch: hb["branch"],
          user_agent: hb["user_agent"] || hb["user_agent_id"],
          is_write: hb["is_write"] || false,
          line_additions: hb["line_additions"],
          line_deletions: hb["line_deletions"],
          lineno: hb["lineno"],
          lines: hb["lines"],
          cursorpos: hb["cursorpos"],
          dependencies: hb["dependencies"] || [],
          project_root_count: hb["project_root_count"],
          source_type: Heartbeat.source_types.fetch("wakapi_import")
        }

        attrs[:fields_hash] = Heartbeat.generate_fields_hash(attrs)

        existing = seen_hashes[attrs[:fields_hash]]
        seen_hashes[attrs[:fields_hash]] = attrs if existing.nil? || attrs[:time] > existing[:time]

        if seen_hashes.size >= BATCH_SIZE
          imported_count += flush_batch(seen_hashes)
          seen_hashes.clear
        end
      rescue => e
        errors << { heartbeat: hb, error: e.message }
      end
    end

    Oj.saj_parse(handler, file_content)
    on_progress&.call(total_count)

    if total_count.zero?
      raise StandardError, "Expected a heartbeat export JSON file."
    end
    imported_count += flush_batch(seen_hashes) if seen_hashes.any?

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    {
      success: true,
      imported_count: imported_count,
      total_count: total_count,
      skipped_count: total_count - imported_count,
      errors: errors,
      time_taken: elapsed.round(2)
    }

  rescue => e
    # Capture partial progress at time of error - some batches may have already been flushed
    # and those heartbeats are in the database, so report accurate counts
    {
      success: false,
      error: e.message,
      imported_count: imported_count,
      total_count: total_count,
      skipped_count: total_count - imported_count,
      errors: errors + [ e.message ]
    }
  end

  def self.count_heartbeats(file_content)
    total_count = 0

    handler = HeartbeatSaxHandler.new do |_hb|
      total_count += 1
    end

    Oj.saj_parse(handler, file_content)
    total_count
  end

  def self.flush_batch(seen_hashes)
    return 0 if seen_hashes.empty?

    records = seen_hashes.values
    user_id = records.first[:user_id]
    records.each do |r|
      timestamp = Time.current
      r[:created_at] = timestamp
      r[:updated_at] = timestamp
    end

    ActiveRecord::Base.logger.silence do
      new_records = []

      User.transaction do
        User.lock.find(user_id)

        existing_hashes = Heartbeat.where(user_id: user_id, fields_hash: records.map { |r| r[:fields_hash] }).pluck(:fields_hash).to_set
        new_records = records.reject { |r| existing_hashes.include?(r[:fields_hash]) }

        if new_records.any?
          Heartbeat.connection.with_settings(async_insert: 0, wait_for_async_insert: 1) do
            Heartbeat.insert_all(new_records)
          end
          Heartbeat.connection.clear_query_cache
          wait_until_visible!(
            user_id,
            new_records.map { |record| record[:fields_hash] },
            expected_min_time: new_records.map { |record| record[:time].to_f }.min
          )
        end
      end

      HeartbeatCacheInvalidator.bump_for(user_id) if new_records.any?
      new_records.length
    end
  end

  def self.wait_until_visible!(user_id, fields_hashes, expected_min_time:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2

    loop do
      visible_count = Heartbeat.where(user_id: user_id, fields_hash: fields_hashes).count
      visible_min_time = Heartbeat.where(user_id: user_id).minimum(:time).to_f
      return if visible_count >= fields_hashes.length && visible_min_time <= expected_min_time

      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end
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
      if inside_heartbeat_array? && @depth == @heartbeat_array_depths.last + 1
        @current_heartbeat = {}
      end
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

    def inside_heartbeat_array?
      @heartbeat_array_depths.any?
    end
  end
end
