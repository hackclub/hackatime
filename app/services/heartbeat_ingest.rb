class HeartbeatIngest
  class InvalidHeartbeatTime < ArgumentError; end

  LAST_LANGUAGE_SENTINEL = "<<LAST_LANGUAGE>>"
  LAST_BRANCH_SENTINEL = "<<LAST_BRANCH>>"
  LAST_PROJECT_SENTINEL = "<<LAST_PROJECT>>"

  # Sane epoch-seconds window: 2001-09-09 .. 2033-05-18. Values outside are
  # client bugs (uptime-like numbers, literal years, ms/µs/ns-scaled epochs).
  EPOCH_SANE_MIN = 1_000_000_000
  EPOCH_SANE_MAX = 2_000_000_000

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
        identity: Heartbeat.identity_key(model_attributes)
      }
    rescue => e
      errors << { heartbeat: heartbeat, error: e.message, type: e.class.name }
      items[index] = Item.new(heartbeat: nil, status: :failed, error: e)
    end

    if entries.any?
      begin
        persisted_by_identity, inserted_identities = persist_direct_heartbeats(entries)
        persisted_count = inserted_identities.length
        duplicate_count = entries.length - persisted_count

        entries.each do |entry|
          items[entry[:index]] = Item.new(
            heartbeat: persisted_by_identity.fetch(entry[:identity]),
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
    source_type = attrs[:entity] == "test.txt" ? :test_entry : :direct_entry
    attrs[:project] = sanitize_project(attrs[:project])

    language_from_placeholder = attrs[:language] == LAST_LANGUAGE_SENTINEL
    resolve_placeholders!(attrs, placeholder_state)

    known_language = attrs[:language] if language_from_placeholder || LanguageUtils.find_name(attrs[:language])
    inferred = LanguageUtils.fill_missing_language(known_language, entity: attrs[:entity])
    attrs[:language] = inferred if inferred.present?

    attrs[:category] = default_category(attrs[:category], type: attrs[:type])
    attrs[:user_agent] = attrs[:user_agent].presence || attrs.delete(:plugin).presence || @request_context[:user_agent].presence
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

  # Heartbeats live in ClickHouse, which has no unique constraints. Identity is
  # enforced here instead: look up existing heartbeats with the same identity,
  # then insert only the new ones. A per-user Postgres advisory lock serialises
  # that lookup-then-insert across concurrent requests and imports, so two
  # identical resends racing each other cannot both be inserted. The lock is a
  # session lock released in `ensure`, so no Postgres transaction is held open
  # around the ClickHouse network calls.
  def with_user_ingest_lock(&block) = self.class.with_user_ingest_lock(@user.id, &block)

  def self.with_user_ingest_lock(user_id)
    connection = ApplicationRecord.connection
    key = connection.quote(advisory_lock_key(user_id))
    connection.execute("SELECT pg_advisory_lock(#{key})")
    yield
  ensure
    connection&.execute("SELECT pg_advisory_unlock(#{key})") if key
  end

  # Namespaced so it can't collide with other advisory locks in the app.
  def self.advisory_lock_key(user_id) = (0x4842 << 48) | Integer(user_id)

  def persist_direct_heartbeats(entries)
    entries_by_identity = entries.group_by { |entry| entry[:identity] }

    with_user_ingest_lock do
      persisted_by_identity = Heartbeat.existing_by_identity(
        user_id: @user.id,
        candidates: entries_by_identity.values.map { |matching| matching.first[:model_attributes] }
      )
      missing_entries = entries_by_identity.filter_map do |identity, matching_entries|
        matching_entries.first unless persisted_by_identity.key?(identity)
      end

      inserted_identities = []
      if missing_entries.any?
        timestamp = Time.current
        rows = Heartbeat.insert_rows!(missing_entries.map { |entry| direct_insert_record(entry, timestamp:) })
        missing_entries.zip(rows).each do |entry, row|
          persisted_by_identity[entry[:identity]] = Heartbeat.instantiate(row.transform_keys(&:to_s))
          inserted_identities << entry[:identity]
        end
      end

      entries_by_identity.each_key { |identity| persisted_by_identity.fetch(identity) }
      if inserted_identities.any? && @schedule_rollup_refresh
        self.class.schedule_rollup_refresh(user: @user)
      end

      [ persisted_by_identity, inserted_identities ]
    end
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
    Heartbeat.row_for_insert(entry[:model_attributes].merge("created_at" => timestamp, "updated_at" => timestamp))
  end

  def ingest_import
    seen = {}
    total_count = 0
    errors = []
    placeholder_state = { contexts: {}, last_project: nil }

    @heartbeats.each do |heartbeat|
      total_count += 1
      attrs = normalize_imported_heartbeat(heartbeat, placeholder_state:)
      existing = seen[attrs[:identity]]
      seen[attrs[:identity]] = attrs if existing.nil? || attrs[:time] > existing[:time]
    rescue => e
      errors << { heartbeat: heartbeat, error: e.message, type: e.class.name }
    end

    persisted_count = flush_import_batch(seen)
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
    user_agent_info = (@user_agents_by_id[hb[:user_agent_id].to_s] || {}).with_indifferent_access
    resolved_user_agent = hb[:user_agent].presence || user_agent_info[:value].presence || hb[:user_agent_id].presence
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
      .except("id", "created_at", "updated_at")
      .symbolize_keys
    normalized[:identity] = Heartbeat.identity_key(import_identity_attributes(model_attributes, source: hb))
    placeholder_fields = []
    placeholder_fields << "language" if hb[:language] == LAST_LANGUAGE_SENTINEL
    placeholder_fields << "branch" if hb[:branch] == LAST_BRANCH_SENTINEL
    if placeholder_fields.any?
      normalized[:placeholder_identity] = Heartbeat.identity_key(
        model_attributes.except(*placeholder_fields).merge(placeholder_fields.index_with { PLACEHOLDER_ANY })
      )
      normalized[:placeholder_fields] = placeholder_fields
    end
    normalized[:legacy_identity] = Heartbeat.identity_key(legacy_import_identity_attributes(
      hb,
      user_agent_info:,
      resolved_user_agent:,
      normalized_time: normalized[:time]
    ))
    update_placeholder_state!(normalized, placeholder_state)
    normalized
  end

  # Imports are large (up to 50k per batch). Existing heartbeats are looked up
  # by time window in ClickHouse and compared by identity in Ruby, under the
  # same per-user lock as direct ingest. A record is a duplicate when either its
  # canonical identity or its legacy (pre-normalisation) identity matches a
  # stored heartbeat, so re-importing an old dump never mints a second row.
  def flush_import_batch(seen)
    return 0 if seen.empty?

    records = seen.values
    with_user_ingest_lock do
      existing = existing_import_identities(records)
      records = records.reject do |record|
        existing.include?(record[:identity]) || existing.include?(record[:legacy_identity]) ||
          (record[:placeholder_identity] && existing.include?(record[:placeholder_identity]))
      end
      next 0 if records.empty?

      timestamp = Time.current
      rows = records.map do |record|
        Heartbeat.row_for_insert(
          record.except(:identity, :legacy_identity, :placeholder_identity, :placeholder_fields)
            .merge(created_at: timestamp, updated_at: timestamp)
        )
      end
      ActiveRecord::Base.logger.silence do
        rows.each_slice(IMPORT_INSERT_BATCH_SIZE) { |slice| Heartbeat.insert_rows!(slice) }
      end
      rows.length
    end
  end

  IMPORT_INSERT_BATCH_SIZE = 10_000

  # Identities of stored heartbeats in the time span of this batch. Stored rows
  # get both their canonical identity and their placeholder-preserving identity
  # (raw <<LAST_LANGUAGE>>/<<LAST_BRANCH>>), so either form of a record matches.
  def existing_import_identities(records)
    times = records.map { |record| record[:time].to_f }
    placeholder_field_sets = records.filter_map { |record| record[:placeholder_fields] }.uniq
    identities = Set.new
    Heartbeat.unscoped.with_excluded
      .where(user_id: @user.id, deleted_at: nil, time: times.min..times.max)
      .in_batches(of: 50_000, order: :asc, cursor: %i[time id]) do |batch|
        batch.each do |heartbeat|
          attributes = heartbeat.attributes
          identities << Heartbeat.identity_key(attributes)
          placeholder_field_sets.each do |fields|
            identities << Heartbeat.identity_key(attributes.except(*fields).merge(fields.index_with { PLACEHOLDER_ANY }))
          end
        end
      end
    identities
  end

  # Stands in for a placeholder-resolved field when comparing identities.
  PLACEHOLDER_ANY = "<<RESOLVED_PLACEHOLDER>>".freeze

  # Import normalization is part of the persisted dedup contract. Keep the
  # pre-parity identity as a lookup alias so re-importing an old dump cannot mint
  # a second row merely because canonical category, project or UA values changed.
  def legacy_import_identity_attributes(hb, user_agent_info:, resolved_user_agent:, normalized_time:)
    legacy_user_agent = legacy_parse_user_agent(resolved_user_agent)
    {
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
    }
  end

  # Placeholder resolution depends on stored history, which can change between
  # identical imports. A record whose source carried <<LAST_LANGUAGE>> or
  # <<LAST_BRANCH>> is therefore compared using whatever was stored for it the
  # first time, not what it resolves to now: see placeholder_identity_keys.
  def import_identity_attributes(model_attributes, source:) = model_attributes

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
