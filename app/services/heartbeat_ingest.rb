class HeartbeatIngest
  class InvalidHeartbeatTime < ArgumentError; end

  LAST_LANGUAGE_SENTINEL = "<<LAST_LANGUAGE>>"
  LAST_BRANCH_SENTINEL = "<<LAST_BRANCH>>"
  LAST_PROJECT_SENTINEL = "<<LAST_PROJECT>>"

  ZED_PROJECT_FIRST_VERSION = Gem::Version.new("0.162.0")
  MACOS_WAKATIME_ZED_FIX_VERSION = Gem::Version.new("5.28.5-alpha.1")

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
    items = Array.new(@heartbeats.length)
    errors = []
    entries = []
    persisted_count = duplicate_count = 0
    placeholder_state = { contexts: {}, last_project: nil }

    @heartbeats.each_with_index do |heartbeat, index|
      attrs = normalize_direct_heartbeat(heartbeat, placeholder_state:)
      model_attributes = validated_model_attributes(attrs)
      attrs = model_attributes.symbolize_keys
      update_placeholder_state!(attrs, placeholder_state)
      entries << {
        index:,
        heartbeat:,
        attrs:,
        model_attributes:,
        fields_hash: Heartbeat.generate_fields_hash(model_attributes)
      }
    rescue => e
      errors << { heartbeat: heartbeat, error: e.message, type: e.class.name }
      items[index] = Item.new(heartbeat: nil, status: :failed, error: e)
    end

    if entries.any?
      begin
        persisted_by_hash, inserted_hashes = persist_direct_heartbeats(entries)
        persisted_count = inserted_hashes.length
        duplicate_count = entries.length - persisted_count

        entries.each do |entry|
          items[entry[:index]] = Item.new(
            heartbeat: persisted_by_hash.fetch(entry[:fields_hash]),
            status: :accepted,
            error: nil
          )
        end
        entries.map { |entry| entry[:attrs][:project] }.uniq.each { |project| queue_project_mapping(project) }
      rescue => e
        entries.each do |entry|
          errors << { heartbeat: entry[:heartbeat], error: e.message, type: e.class.name }
          items[entry[:index]] = Item.new(heartbeat: nil, status: :failed, error: e)
        end
      end
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

  def normalize_direct_heartbeat(heartbeat, placeholder_state:)
    attrs = strip_null_bytes(heartbeat.to_h.with_indifferent_access)
    attrs[:time] = normalize_heartbeat_time(attrs[:time])
    attrs[:user_agent] = attrs[:user_agent].presence || attrs.delete(:plugin).presence || @request_context[:user_agent].presence
    remap_macos_wakatime_zed_heartbeat!(attrs)
    source_type = attrs[:entity] == "test.txt" ? :test_entry : :direct_entry
    attrs[:project] = sanitize_project(attrs[:project])

    resolve_placeholders!(attrs, placeholder_state)

    inferred = LanguageUtils.fill_missing_language(attrs[:language], entity: attrs[:entity])
    attrs[:language] = inferred if inferred.present?

    attrs[:category] = default_category(attrs[:category], type: attrs[:type])
    parsed_ua = WakatimeUserAgentParser.parse(attrs[:user_agent], category: attrs[:category])

    attrs.merge(
      user_id: @user.id,
      source_type:,
      ip_address: @request_context[:ip_address],
      ja4_id: resolved_ja4&.id,
      ai_model: attrs[:ai_model].presence || parsed_ua[:ai_model],
      editor: parsed_ua[:editor].presence || attrs[:editor].presence,
      operating_system: parsed_ua[:os].presence || attrs[:operating_system].presence,
      machine: @request_context[:machine].presence || attrs[:machine].presence
    ).slice(*Heartbeat.column_names.map(&:to_sym))
  end

  def persist_direct_heartbeats(entries)
    entries_by_hash = entries.group_by { |entry| entry[:fields_hash] }
    hashes = entries_by_hash.keys
    persisted_by_hash = @user.heartbeats.where(fields_hash: hashes).index_by(&:fields_hash)
    missing_entries = entries_by_hash.filter_map do |fields_hash, matching_entries|
      matching_entries.first unless persisted_by_hash.key?(fields_hash)
    end

    inserted_by_hash = {}
    if missing_entries.any?
      timestamp = Time.current
      result = with_heartbeat_unique_by do |unique_by|
        records = missing_entries.map { |entry| direct_insert_record(entry, timestamp:) }
        Heartbeat.insert_all(records, unique_by:, returning: Heartbeat.column_names)
      end
      inserted_by_hash = result.to_a.index_by { |attributes| attributes.fetch("fields_hash") }
        .transform_values { |attributes| Heartbeat.new(attributes) }
      persisted_by_hash.merge!(inserted_by_hash)

      # Another request can win the conflict after our prefetch but before the
      # insert. ON CONFLICT skips those rows, so fetch the winners once.
      unresolved_hashes = missing_entries.map { |entry| entry[:fields_hash] } - inserted_by_hash.keys
      if unresolved_hashes.any?
        persisted_by_hash.merge!(
          @user.heartbeats.where(fields_hash: unresolved_hashes).index_by(&:fields_hash)
        )
      end
    end

    hashes.each { |fields_hash| persisted_by_hash.fetch(fields_hash) }
    if inserted_by_hash.any? && @schedule_rollup_refresh
      self.class.schedule_rollup_refresh(user: @user)
    end

    [ persisted_by_hash, inserted_by_hash.keys ]
  end

  # insert_all deliberately skips the Active Record lifecycle. Run the normal
  # validation chain against the type-cast model before constructing the bulk
  # record. The user association avoids one existence query per heartbeat.
  # Persistence callbacks remain explicit in the record-construction and
  # batch-persistence methods so the actual insert stays multi-row.
  def validated_model_attributes(attrs)
    heartbeat = Heartbeat.new(attrs)
    heartbeat.user = @user
    heartbeat.validate!
    heartbeat.attributes
  end

  def direct_insert_record(entry, timestamp:)
    entry[:model_attributes]
      .except("id", "fields_hash", "created_at", "updated_at", "time_epoch")
      .merge(
        "fields_hash" => entry[:fields_hash],
        "created_at" => timestamp,
        "updated_at" => timestamp,
        **partition_attrs(entry[:attrs][:time]).stringify_keys
      )
  end

  def ingest_import
    seen_hashes = {}
    total_count = 0
    errors = []
    placeholder_state = { contexts: {}, last_project: nil }

    @heartbeats.each do |heartbeat|
      total_count += 1
      attrs = normalize_imported_heartbeat(heartbeat, placeholder_state:)
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

  def normalize_imported_heartbeat(heartbeat, placeholder_state: { contexts: {}, last_project: nil })
    hb = heartbeat.respond_to?(:with_indifferent_access) ? heartbeat.with_indifferent_access : heartbeat.to_h.with_indifferent_access
    source_heartbeat = hb.dup
    user_agent_info = (@user_agents_by_id[hb[:user_agent_id].to_s] || {}).with_indifferent_access
    resolved_user_agent = hb[:user_agent].presence || user_agent_info[:value].presence || hb[:user_agent_id].presence
    remap_macos_wakatime_zed_heartbeat!(hb, user_agent: resolved_user_agent)
    parsed_user_agent = parse_user_agent(resolved_user_agent, category: hb[:category])
    derived_ai_editor = parsed_user_agent[:editor].presence if parsed_user_agent[:ai_model].present?

    attrs = {
      ai_model: hb[:ai_model].presence || parsed_user_agent[:ai_model].presence,
      ai_session: hb[:ai_session],
      ai_subscription_plan: hb[:ai_subscription_plan],
      ai_input_tokens: hb[:ai_input_tokens],
      ai_output_tokens: hb[:ai_output_tokens],
      ai_prompt_length: hb[:ai_prompt_length],
      ai_line_changes: hb[:ai_line_changes],
      human_line_changes: hb[:human_line_changes],
      user_id: @user.id,
      time: normalize_heartbeat_time(hb[:time]),
      entity: hb[:entity],
      type: hb[:type],
      category: hb[:category].presence,
      project: sanitize_project(hb[:project]),
      language: hb[:language],
      editor: derived_ai_editor || hb[:editor].presence || user_agent_info[:editor].presence || parsed_user_agent[:editor].presence,
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
    resolve_placeholders!(attrs, placeholder_state)
    attrs[:language] = LanguageUtils.fill_missing_language(attrs[:language], entity: attrs[:entity])
    attrs[:category] = default_category(attrs[:category], type: attrs[:type])
    model_attributes = validated_model_attributes(attrs)
    normalized = model_attributes
      .except("id", "fields_hash", "created_at", "updated_at", "time_epoch")
      .symbolize_keys
    normalized[:fields_hash] = import_fields_hash(model_attributes, source: source_heartbeat)
    normalized[:legacy_fields_hash] = legacy_import_fields_hash(
      source_heartbeat,
      user_agent_info:,
      resolved_user_agent:,
      normalized_time: normalized[:time]
    )
    update_placeholder_state!(normalized, placeholder_state)
    normalized
  end

  def flush_import_batch(seen_hashes)
    return 0 if seen_hashes.empty?

    records = seen_hashes.values
    compatible_hashes = records.flat_map { |record| [ record[:fields_hash], record[:legacy_fields_hash] ] }.compact.uniq
    existing_hashes = compatible_hashes.each_slice(10_000).flat_map do |hashes|
      @user.heartbeats.where(fields_hash: hashes).pluck(:fields_hash)
    end.to_set
    records = records.reject do |record|
      existing_hashes.include?(record[:fields_hash]) || existing_hashes.include?(record[:legacy_fields_hash])
    end
    return 0 if records.empty?

    timestamp = Time.current
    ActiveRecord::Base.logger.silence do
      # Build records inside the retry block so a cutover-time schema refresh
      # recomputes both the conflict target and the time_epoch partition column.
      with_heartbeat_unique_by do |unique_by|
        insert_records = records.map do |record|
          record.except(:legacy_fields_hash)
            .merge(created_at: timestamp, updated_at: timestamp, **partition_attrs(record[:time]))
        end
        Heartbeat.insert_all(insert_records, unique_by:).length
      end
    end
  end

  # Import normalization is part of the persisted dedup contract. Keep the
  # pre-parity hash as a lookup alias so re-importing an old dump cannot mint a
  # second row merely because canonical category, project or UA values changed.
  def legacy_import_fields_hash(hb, user_agent_info:, resolved_user_agent:, normalized_time:)
    legacy_user_agent = legacy_parse_user_agent(resolved_user_agent)
    Heartbeat.generate_fields_hash(
      user_id: @user.id,
      time: normalized_time,
      entity: hb[:entity],
      type: hb[:type],
      category: hb[:category] || "coding",
      project: hb[:project],
      language: LanguageUtils.legacy_fill_missing_language(hb[:language], entity: hb[:entity]),
      editor: hb[:editor].presence || user_agent_info[:editor].presence || legacy_user_agent[:editor].presence,
      operating_system: hb[:operating_system].presence || user_agent_info[:os].presence || legacy_user_agent[:os].presence,
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
      project_root_count: hb[:project_root_count]
    )
  end

  # Resolved placeholders are useful metadata, but database-backed resolution
  # can change between identical imports. Keep the raw sentinel in the persisted
  # identity so fields_hash remains a pure function of the dump row.
  def import_fields_hash(model_attributes, source:)
    hash_attributes = model_attributes.dup
    hash_attributes["language"] = LAST_LANGUAGE_SENTINEL if source[:language] == LAST_LANGUAGE_SENTINEL
    hash_attributes["branch"] = LAST_BRANCH_SENTINEL if source[:branch] == LAST_BRANCH_SENTINEL
    Heartbeat.generate_fields_hash(hash_attributes)
  end

  def legacy_parse_user_agent(user_agent)
    return { editor: nil, os: nil } if user_agent.blank?

    if matches = user_agent.match(/wakatime\/[^ ]+ \(([^)]+)\)(?: [^ ]+ ([^\/]+)(?:\/([^\/]+))?)?/)
      return { os: matches[1].split("-").first, editor: matches[2].presence }
    end

    browser = user_agent.match(/^([^\/]+)\/([^\/\s]+)/)
    return { editor: nil, os: nil } unless browser
    return { editor: browser[2], os: browser[1] } unless user_agent.include?("wakatime")

    full_os = user_agent.split(" ")[1]
    return { editor: nil, os: nil } if full_os.blank?

    { editor: browser[1].downcase, os: full_os.include?("_") ? full_os.split("_").first : full_os }
  end

  def heartbeat_unique_by
    time_epoch_column? ? UNIQUE_BY_COMPOSITE : UNIQUE_BY_LEGACY
  end

  def time_epoch_column? = Heartbeat.column_names.include?("time_epoch")

  # The hypertable partition column must arrive populated (TimescaleDB routes to
  # a chunk before row triggers fire). Bulk insert/insert_all bypass model
  # callbacks, so ingest supplies time_epoch explicitly once the column exists.
  # No-op on the pre-cutover / dev-and-test plain table.
  def partition_attrs(time)
    return {} unless time_epoch_column? && time.present?
    { time_epoch: time.to_f.floor }
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
    t = Float(value)
    raise InvalidHeartbeatTime unless t.finite?
    return t if t >= EPOCH_SANE_MIN && t < EPOCH_SANE_MAX

    # ms / µs / ns-scaled epochs are mechanically repairable
    [ 1e3, 1e6, 1e9 ].each do |scale|
      scaled = t / scale
      return scaled if scaled >= EPOCH_SANE_MIN && scaled < EPOCH_SANE_MAX
    end

    raise InvalidHeartbeatTime, "time must be Unix epoch seconds between #{EPOCH_SANE_MIN} and #{EPOCH_SANE_MAX - 1}"
  rescue TypeError, ArgumentError => e
    raise e if e.is_a?(InvalidHeartbeatTime)
    raise InvalidHeartbeatTime, "time must be a Unix epoch timestamp"
  end

  def normalize_heartbeat_time(value)
    if value.is_a?(String) && !value.strip.match?(/\A[+-]?(?:\d+(?:\.\d*)?|\.\d+)\z/)
      normalize_epoch_time(Time.parse(value).to_f)
    else
      normalize_epoch_time(value)
    end
  rescue InvalidHeartbeatTime
    raise
  rescue TypeError, ArgumentError
    raise InvalidHeartbeatTime, "time must be a Unix epoch timestamp or parseable date"
  end

  def strip_null_bytes(value)
    case value
    when String then value.delete("\0")
    when Array then value.map { |item| strip_null_bytes(item) }
    when Hash then value.transform_values { |item| strip_null_bytes(item) }
    else value
    end
  end

  def parse_user_agent(user_agent, category: nil)
    return { editor: nil, os: nil, ai_model: nil } if user_agent.blank?
    parsed = WakatimeUserAgentParser.parse(user_agent, category:)
    { editor: parsed[:editor].presence, os: parsed[:os].presence, ai_model: parsed[:ai_model].presence }
  end

  def default_category(category, type:)
    return category if category.present?
    return "browsing" if %w[domain url].include?(type)

    "coding"
  end

  def remap_macos_wakatime_zed_heartbeat!(heartbeat, user_agent: heartbeat[:user_agent])
    return unless heartbeat[:type] == "app"

    zed_version = product_version(user_agent, "Zed")
    macos_wakatime_version = product_version(user_agent, "macos-wakatime")
    return unless zed_version && macos_wakatime_version
    return unless zed_version >= ZED_PROJECT_FIRST_VERSION
    return unless macos_wakatime_version < MACOS_WAKATIME_ZED_FIX_VERSION

    heartbeat[:entity], heartbeat[:project] = heartbeat[:project], heartbeat[:entity]
  end

  def product_version(user_agent, product)
    version = user_agent.to_s.match(/(?:\A|\s)#{Regexp.escape(product)}\/([^\s]+)/i)&.captures&.first
    Gem::Version.new(version&.split("+")&.first)
  rescue ArgumentError
    nil
  end

  # `<<LAST_PROJECT>>` stays persisted by design, but language and branch need
  # the last real project as context. This avoids turning browser time into a
  # guessed project while preventing sentinel values from fragmenting reports.
  def resolve_placeholders!(attrs, state)
    context_project = attrs[:project] == LAST_PROJECT_SENTINEL ? state[:last_project] : attrs[:project]
    return unless attrs[:language] == LAST_LANGUAGE_SENTINEL || attrs[:branch] == LAST_BRANCH_SENTINEL

    context = placeholder_context_for(context_project, state)
    attrs[:language] = context[:language] if attrs[:language] == LAST_LANGUAGE_SENTINEL
    attrs[:branch] = context[:branch] if attrs[:branch] == LAST_BRANCH_SENTINEL
  end

  def placeholder_context_for(project, state)
    return {} if project.blank?

    context = state[:contexts][project] ||= {}
    unless context.key?(:language)
      context[:language] = @user.heartbeats.where(project: project)
        .where.not(language: [ nil, "", LAST_LANGUAGE_SENTINEL ]).order(time: :desc).pick(:language)
    end
    unless context.key?(:branch)
      context[:branch] = @user.heartbeats.where(project: project)
        .where.not(branch: [ nil, "", LAST_BRANCH_SENTINEL ]).order(time: :desc).pick(:branch)
    end
    context
  end

  def update_placeholder_state!(attrs, state)
    project = attrs[:project]
    state[:last_project] = project if project.present? && project != LAST_PROJECT_SENTINEL
    context_project = project == LAST_PROJECT_SENTINEL ? state[:last_project] : project
    return if context_project.blank?

    context = state[:contexts][context_project] ||= {}
    context[:language] = attrs[:language] if attrs[:language].present? && attrs[:language] != LAST_LANGUAGE_SENTINEL
    context[:branch] = attrs[:branch] if attrs[:branch].present? && attrs[:branch] != LAST_BRANCH_SENTINEL
  end

  def resolved_ja4
    return @resolved_ja4 if defined?(@resolved_ja4)

    @resolved_ja4 = Ja4.resolve(@request_context[:ja4])
  end

  def sanitize_project(project_name)
    project_name&.gsub(/[[:cntrl:]]/, "")&.strip
  end

  def queue_project_mapping(project_name)
    return if ProjectRepoMapping::IGNORED_PROJECTS.include?(project_name)

    project_digest = Digest::SHA256.hexdigest(project_name)
    Rails.cache.fetch("attempt_project_repo_mapping_job_#{@user.id}_#{project_digest}", expires_in: 1.hour) do
      AttemptProjectRepoMappingJob.perform_later(@user.id, project_name)
    end
  rescue => e
    Rails.error.report(e, handled: true, context: { message: "Error queuing project mapping" })
  end
end
