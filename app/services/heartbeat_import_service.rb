class HeartbeatImportService
  BATCH_SIZE = 50_000

  def self.import_from_file(file_content, user)
    unless Rails.env.development?
      raise StandardError, "Not dev env, not running"
    end

    user_id = user.id
    indexed_attrs = Heartbeat.indexed_attributes
    imported_count = 0
    total_count = 0
    errors = []
    seen_hashes = {}

    handler = HeartbeatSaxHandler.new do |hb|
      total_count += 1

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
        machine: hb["machine"],
        branch: hb["branch"],
        user_agent: hb["user_agent"],
        is_write: hb["is_write"] || false,
        line_additions: hb["line_additions"],
        line_deletions: hb["line_deletions"],
        lineno: hb["lineno"],
        lines: hb["lines"],
        cursorpos: hb["cursorpos"],
        dependencies: hb["dependencies"] || [],
        project_root_count: hb["project_root_count"],
        source_type: 1
      }

      string_attrs = attrs.transform_keys(&:to_s)
      hash_input = indexed_attrs.each_with_object({}) { |k, h| h[k] = string_attrs[k] }
      fields_hash = Digest::MD5.hexdigest(Oj.dump(hash_input, mode: :compat))
      attrs[:fields_hash] = fields_hash

      existing = seen_hashes[fields_hash]
      seen_hashes[fields_hash] = attrs if existing.nil? || attrs[:time] > existing[:time]

      if seen_hashes.size >= BATCH_SIZE
        imported_count += flush_batch(seen_hashes)
        seen_hashes.clear
      end
    end

    Oj.saj_parse(handler, file_content)

    imported_count += flush_batch(seen_hashes) if seen_hashes.any?

    {
      success: true,
      imported_count: imported_count,
      total_count: total_count,
      skipped_count: total_count - imported_count,
      errors: errors
    }

  rescue => e
    {
      success: false,
      error: e.message,
      imported_count: 0,
      total_count: 0,
      skipped_count: 0,
      errors: [ e.message ]
    }
  end

  def self.flush_batch(seen_hashes)
    return 0 if seen_hashes.empty?

    records = seen_hashes.values
    records = Heartbeat.batch_resolve_dimensions(records)

    now = Time.current
    records.each do |r|
      r[:created_at] = now
      r[:updated_at] = now
    end

    result = Heartbeat.upsert_all(records, unique_by: [ :fields_hash ])
    result.length
  end

  class HeartbeatSaxHandler < Oj::Saj
    def initialize(&block)
      @block = block
      @in_heartbeats = false
      @depth = 0
      @current_heartbeat = nil
      @current_key = nil
      @array_depth = 0
    end

    def hash_start(key)
      if @in_heartbeats && @depth == 2
        @current_heartbeat = {}
      end
      @depth += 1
    end

    def hash_end(key)
      @depth -= 1
      if @in_heartbeats && @depth == 2 && @current_heartbeat
        @block.call(@current_heartbeat)
        @current_heartbeat = nil
      end
    end

    def array_start(key)
      if key == "heartbeats" && @depth == 1
        @in_heartbeats = true
      elsif @current_heartbeat && @current_key
        @current_heartbeat[@current_key] = []
        @array_depth += 1
      end
      @depth += 1
    end

    def array_end(key)
      @depth -= 1
      if key == "heartbeats"
        @in_heartbeats = false
      end
      @array_depth = 0 if @array_depth > 0
    end

    def add_value(value, key)
      return unless @current_heartbeat

      if key
        @current_key = key
        if @array_depth > 0 && @current_heartbeat[@current_key].is_a?(Array)
          @current_heartbeat[@current_key] << value
        else
          @current_heartbeat[key] = value
        end
      elsif @array_depth > 0 && @current_key && @current_heartbeat[@current_key].is_a?(Array)
        @current_heartbeat[@current_key] << value
      end
    end
  end
end
