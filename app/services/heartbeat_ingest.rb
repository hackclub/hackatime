class HeartbeatIngest
  LAST_LANGUAGE_SENTINEL = "<<LAST_LANGUAGE>>"

  # Sane epoch-seconds window: 2001-09-09 .. 2033-05-18. Values outside are
  # client bugs (uptime-like numbers, literal years, ms/µs/ns-scaled epochs).
  EPOCH_SANE_MIN = 1_000_000_000
  EPOCH_SANE_MAX = 2_000_000_000

  # The heartbeats dedup unique index changes from (fields_hash) to
  # (fields_hash, time_epoch) during the hypertable migration.
  UNIQUE_BY_LEGACY = [ :fields_hash ].freeze
  UNIQUE_BY_COMPOSITE = %i[fields_hash time_epoch].freeze

  Result = Data.define(:total_count, :persisted_count, :duplicate_count, :failed_count, :errors, :items)
  Item = Data.define(:heartbeat, :status, :error)

  def self.call(...) = new(...).call
  def self.schedule_rollup_refresh(user:) = DashboardRollupRefreshJob.schedule_for(user.id)

  def self.normalize_imported_heartbeat(user:, heartbeat:, user_agents_by_id: {}) = new(user:, mode: :import, heartbeats: [], user_agents_by_id:).send(:normalize_imported_heartbeat, heartbeat)

  def initialize(user:, mode:, heartbeats:, request_context: {}, user_agents_by_id: {}, schedule_rollup_refresh: true)
    @user = user
    @mode = mode
    @heartbeats = heartbeats
    @request_context = request_context.with_indifferent_access
    @user_agents_by_id = user_agents_by_id
    @schedule_rollup_refresh = schedule_rollup_refresh
  end

  def call
    case @mode
    when :direct then ingest_direct
    when :import then ingest_import
    else raise ArgumentError, "Unsupported heartbeat ingest mode: #{@mode.inspect}"
    end
  end

  private

  def ingest_direct
    items, errors = [], []
    persisted_count = duplicate_count = 0
    last_language = nil

    @heartbeats.each do |heartbeat|
      attrs = normalize_direct_heartbeat(heartbeat, last_language:)
      persisted, duplicate = persist_direct_heartbeat(attrs)
      last_language = attrs[:language] if attrs[:language].present?
      duplicate ? duplicate_count += 1 : persisted_count += 1
      items << Item.new(heartbeat: persisted, status: :accepted, error: nil)
      queue_project_mapping(attrs[:project])
    rescue => e
      errors << { heartbeat: heartbeat, error: e.message, type: e.class.name }
      items << Item.new(heartbeat: nil, status: :failed, error: e)
    end

    Result.new(
      total_count: @heartbeats.length,
      persisted_count:,
      duplicate_count:,
      failed_count: errors.length,
      errors:,
      items:
    )
  end

  def normalize_direct_heartbeat(heartbeat, last_language:)
    attrs = heartbeat.to_h.with_indifferent_access
    attrs[:time] = normalize_epoch_time(attrs[:time]) if attrs[:time].present?
    source_type = attrs[:entity] == "test.txt" ? :test_entry : :direct_entry

    if attrs[:language] == LAST_LANGUAGE_SENTINEL
      attrs[:language] = last_language || @user.heartbeats
        .where.not(language: [ nil, "", LAST_LANGUAGE_SENTINEL ]).order(time: :desc).pick(:language)
    end

    if attrs[:language].blank? || attrs[:language] == "Unknown"
      inferred = LanguageUtils.detect_from_extension(attrs[:entity])
      attrs[:language] = inferred if inferred
    end

    attrs[:user_agent] ||= attrs.delete(:plugin)
    parsed_ua = WakatimeService.parse_user_agent(attrs[:user_agent])
    attrs[:category] ||= "coding"
    attrs[:project] = attrs[:project]&.gsub(/[[:cntrl:]]/, "")&.strip

    attrs.merge(
      user_id: @user.id,
      source_type:,
      ip_address: @request_context[:ip_address],
      ja4_id: resolved_ja4&.id,
      editor: parsed_ua[:editor],
      operating_system: parsed_ua[:os],
      machine: @request_context[:machine]
    ).slice(*Heartbeat.column_names.map(&:to_sym))
  end

  def persist_direct_heartbeat(attrs)
    fields_hash = Heartbeat.generate_fields_hash(Heartbeat.new(attrs).attributes)
    existing = @user.heartbeats.find_by(fields_hash: fields_hash)
    return [ existing, true ] if existing

    now = Time.current
    result = with_heartbeat_unique_by do |unique_by|
      Heartbeat.insert(
        attrs.merge(fields_hash:, created_at: now, updated_at: now),
        unique_by:, returning: Heartbeat.column_names
      )
    end

    persisted = result.any? ? Heartbeat.new(result.first) : @user.heartbeats.find_by!(fields_hash:)
    self.class.schedule_rollup_refresh(user: @user) if result.any? && @schedule_rollup_refresh
    [ persisted, !result.any? ]
  end

  def ingest_import
    seen_hashes = {}
    total_count = 0
    errors = []

    @heartbeats.each do |heartbeat|
      total_count += 1
      attrs = normalize_imported_heartbeat(heartbeat)
      existing = seen_hashes[attrs[:fields_hash]]
      seen_hashes[attrs[:fields_hash]] = attrs if existing.nil? || attrs[:time] > existing[:time]
    rescue => e
      errors << { heartbeat: heartbeat, error: e.message, type: e.class.name }
    end

    persisted_count = flush_import_batch(seen_hashes)
    self.class.schedule_rollup_refresh(user: @user) if persisted_count.positive? && @schedule_rollup_refresh

    Result.new(
      total_count:,
      persisted_count:,
      duplicate_count: total_count - persisted_count - errors.length,
      failed_count: errors.length,
      errors:,
      items: []
    )
  end

  def normalize_imported_heartbeat(heartbeat)
    hb = heartbeat.respond_to?(:with_indifferent_access) ? heartbeat.with_indifferent_access : heartbeat.to_h.with_indifferent_access
    user_agent_info = (@user_agents_by_id[hb[:user_agent_id].to_s] || {}).with_indifferent_access
    resolved_user_agent = hb[:user_agent].presence || user_agent_info[:value].presence || hb[:user_agent_id].presence
    parsed_user_agent = parse_user_agent(resolved_user_agent)

    attrs = {
      user_id: @user.id,
      time: normalize_epoch_time(hb[:time].is_a?(String) ? Time.parse(hb[:time]).to_f : hb[:time]),
      entity: hb[:entity],
      type: hb[:type],
      category: hb[:category] || "coding",
      project: hb[:project],
      language: LanguageUtils.fill_missing_language(hb[:language], entity: hb[:entity]),
      editor: hb[:editor].presence || user_agent_info[:editor].presence || parsed_user_agent[:editor].presence,
      operating_system: hb[:operating_system].presence || user_agent_info[:os].presence || parsed_user_agent[:os].presence,
      machine: hb[:machine].presence || hb[:machine_name_id].presence,
      branch: hb[:branch],
      user_agent: resolved_user_agent,
      is_write: hb[:is_write] || false,
      line_additions: hb[:line_additions],
      line_deletions: hb[:line_deletions],
      lineno: hb[:lineno],
      lines: hb[:lines],
      cursorpos: hb[:cursorpos],
      dependencies: hb[:dependencies] || [],
      project_root_count: hb[:project_root_count],
      source_type: Heartbeat.source_types.fetch("wakapi_import")
    }
    attrs[:fields_hash] = Heartbeat.generate_fields_hash(attrs)
    attrs
  end

  def flush_import_batch(seen_hashes)
    return 0 if seen_hashes.empty?
    timestamp = Time.current
    records = seen_hashes.values.map { |r| r.merge(created_at: timestamp, updated_at: timestamp) }
    ActiveRecord::Base.logger.silence do
      with_heartbeat_unique_by { |unique_by| Heartbeat.insert_all(records, unique_by:).length }
    end
  end

  def heartbeat_unique_by
    Heartbeat.column_names.include?("time_epoch") ? UNIQUE_BY_COMPOSITE : UNIQUE_BY_LEGACY
  end

  # Rails resolves `unique_by:` against its schema cache, which goes stale the
  # moment the hypertable cutover swaps the table under us. Refresh the cache
  # and retry once so in-flight processes self-heal without a restart.
  def with_heartbeat_unique_by
    yield heartbeat_unique_by
  rescue ActiveRecord::StatementInvalid, ArgumentError => e
    Heartbeat.reset_column_information
    # Inside an open (now aborted) transaction a retry cannot succeed; re-raise
    # and let the caller retry with the already-refreshed schema cache.
    raise if Heartbeat.connection.transaction_open?

    Rails.logger.warn("HeartbeatIngest unique_by fallback: #{e.class}: #{e.message}")
    yield heartbeat_unique_by
  end

  def normalize_epoch_time(value)
    t = value.to_f
    return t if t >= EPOCH_SANE_MIN && t < EPOCH_SANE_MAX

    # ms / µs / ns-scaled epochs are mechanically repairable
    [ 1e3, 1e6, 1e9 ].each do |scale|
      scaled = t / scale
      return scaled if scaled >= EPOCH_SANE_MIN && scaled < EPOCH_SANE_MAX
    end
    t
  end

  def parse_user_agent(user_agent)
    return { editor: nil, os: nil } if user_agent.blank?
    parsed = WakatimeService.parse_user_agent(user_agent)
    { editor: parsed[:editor].presence, os: parsed[:os].presence }
  end

  def resolved_ja4
    return @resolved_ja4 if defined?(@resolved_ja4)

    @resolved_ja4 = Ja4.resolve(@request_context[:ja4])
  end

  def queue_project_mapping(project_name)
    return if project_name.blank?
    Rails.cache.fetch("attempt_project_repo_mapping_job_#{@user.id}_#{project_name}", expires_in: 1.hour) { AttemptProjectRepoMappingJob.perform_later(@user.id, project_name) }
  rescue => e
    Rails.error.report(e, handled: true, context: { message: "Error queuing project mapping" })
  end
end
