class HeartbeatRepository
  COLUMNS = [ *HeartbeatRow::COLUMNS, "version" ].freeze
  IDENTITY_COLUMNS = [ *COLUMNS, "fields_hash" ].freeze
  STORAGE_COLUMNS = [ *COLUMNS, "dependencies_is_null", "dependencies_json" ].freeze
  STORE_CONTROL_COLUMNS = %w[
    fields_hash alias_hashes payload_hash canonicalized duplicate_of
    ja4_nullification_version heartbeats_version heartbeats_by_time_version store_version
  ].freeze
  STORE_COLUMNS = [ *STORAGE_COLUMNS, *STORE_CONTROL_COLUMNS ].freeze
  QUERY_LAYOUTS = {
    "heartbeats" => "heartbeats_version",
    "heartbeats_by_time" => "heartbeats_by_time_version"
  }.freeze
  SOURCE_TYPES = { "direct_entry" => 0, "wakapi_import" => 1, "test_entry" => 2 }.freeze
  BROWSER_EDITORS = Heartbeatable::BROWSER_EDITORS
  VALID_TIME_MAX = 253_402_300_799
  INSERT_RETRY_LIMIT = 5
  INGEST_INSERT_RETRY_LIMIT = 1
  INGEST_TIMEOUT = 2
  MUTATION_INSERT_RETRY_LIMIT = 2
  MUTATION_TIMEOUT = 5
  QUERY_BATCH_SIZE = 1_000
  INSERT_BATCH_SIZE = 10_000
  PARTITIONED_INSERTS = {
    "heartbeats" => "time",
    "heartbeats_by_time" => "time",
    "heartbeat_store" => "created_at"
  }.freeze
  RETRYABLE_INSERT_ERROR = /(?:UNKNOWN_STATUS_OF_INSERT|TIMEOUT_EXCEEDED|NETWORK_ERROR|SOCKET_TIMEOUT)/

  def self.clickhouse?
    return ENV["CLICKHOUSE_TEST"] == "1" if Rails.env.test?

    ENV.fetch("HEARTBEAT_STORE", "postgresql") == "clickhouse"
  end

  def self.current
    @current ||= new
  end

  def self.ensure_writes_enabled!
    raise "Heartbeat writes are stopped" if ENV["HEARTBEAT_WRITES_STOPPED"] == "1"
  end

  def self.ensure_mutations_enabled!
    raise "Heartbeat mutations are stopped" if ENV["HEARTBEAT_MUTATIONS_STOPPED"] == "1"
  end

  def initialize(client: ClickHouse::Client.current)
    @client = client
    @mutation_retry_key = "heartbeat_repository_mutation_retry_#{object_id}".to_sym
  end

  def all(with_deleted: false)
    Scope.new(self, with_deleted:)
  end

  def for_user(user_id)
    all.where(user_id:)
  end

  def rows(scope, columns: COLUMNS, order: nil, limit: nil, offset: nil)
    selected = columns.any? { |column| column.to_s == "dependencies" } ?
      [ *columns, "dependencies_is_null", "dependencies_json" ] : columns
    attributes_rows = select_rows(scope, select: selected, order:, limit:, offset:)
    attributes_rows.map do |attributes|
      deserialize_dependencies!(attributes)
      HeartbeatRow.new(attributes.except("version"))
    end
  end

  def each_row(scope, columns: COLUMNS, order: nil, limit: nil, offset: nil)
    return enum_for(__method__, scope, columns:, order:, limit:, offset:) unless block_given?

    selected = columns.any? { |column| column.to_s == "dependencies" } ?
      [ *columns, "dependencies_is_null", "dependencies_json" ] : columns
    @client.each_json_each_row(scope.sql(select: selected, order:, limit:, offset:)) do |attributes|
      deserialize_dependencies!(attributes)
      yield HeartbeatRow.new(attributes.except("version"))
    end
  end

  def pluck(scope, columns, order: nil, limit: nil, offset: nil)
    selected_columns = columns.map(&:to_s)
    if selected_columns.include?("dependencies")
      selected_columns += %w[dependencies_is_null dependencies_json]
    end
    select = selected_columns.map { |column| select_expression(column) }
    projections = columns.map do |column|
      name = column.to_s
      [ expression_alias(column), name ]
    end
    selected_rows = select_rows(scope, select:, order:, limit:, offset:)
    selected_rows.map do |row|
      values = projections.map do |alias_name, name|
        if name == "dependencies"
          next nil if row["dependencies_is_null"]
          next JSON.parse(row["dependencies_json"]) if row["dependencies_json"]
        end
        COLUMNS.include?(name) ? HeartbeatRow.deserialize(name, row[alias_name]) : row[alias_name]
      end
      values.length == 1 ? values.first : values
    end
  end

  def aggregate(scope, expression, alias_name: "value")
    @client.select(scope.sql(select: [ "#{expression} AS #{identifier(alias_name)}" ], order: [])).first&.fetch(alias_name, nil)
  end

  def grouped_count(scope, columns)
    groups = columns.map { |column| identifier(column) }
    rows = @client.select(scope.sql(select: [ *groups, "count() AS count" ], group: groups, order: groups))
    rows.to_h do |row|
      key = columns.map { |column| row.fetch(column.to_s) }
      [ key.length == 1 ? key.first : key, row.fetch("count").to_i ]
    end
  end

  def duration_seconds(scope)
    group = scope.group_values
    window = if group.empty?
      "ORDER BY time, id"
    elsif group.one?
      "PARTITION BY #{identifier(group.first)} ORDER BY time, id"
    else
      raise NotImplementedError, "Multiple group values are not supported"
    end
    grouped_column = group.first
    select = [ "time", "id" ]
    select << identifier(grouped_column) if grouped_column
    base_scope = scope.with_valid_timestamps.unscope(:group, :select, :order)
    diffs = <<~SQL.squish
      SELECT #{grouped_column ? "#{identifier(grouped_column)} AS grouped_time," : ""}
             least(greatest(time - lagInFrame(time, 1, time) OVER (
               #{window} ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
             ), 0), #{Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
      FROM (#{base_scope.sql(select:)}) heartbeat_rows
    SQL
    if grouped_column
      @client.select(<<~SQL.squish).to_h { |row| [ row["grouped_time"], row["duration"].to_i ] }
        SELECT grouped_time, toInt64(round(COALESCE(sum(diff), 0))) AS duration
        FROM (#{diffs}) GROUP BY grouped_time
      SQL
    else
      @client.select("SELECT toInt64(round(COALESCE(sum(diff), 0))) AS duration FROM (#{diffs})")
        .first.fetch("duration").to_i
    end
  end

  def attributed_durations(scope, field)
    field = field.to_s
    validate_column!(field)
    base = scope.with_valid_timestamps.sql(select: [ "id", "time", identifier(field) ])
    @client.select(<<~SQL.squish).to_h { |row| [ row["bucket"], row["duration"].to_i ] }
      SELECT bucket, toInt64(round(COALESCE(sum(diff), 0))) AS duration
      FROM (
        SELECT #{identifier(field)} AS bucket,
               least(greatest(time - lagInFrame(time, 1, time) OVER (
                 ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
               ), 0), #{Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
        FROM (#{base}) heartbeat_rows
      )
      WHERE bucket IS NOT NULL AND bucket != ''
      GROUP BY bucket
    SQL
  end

  def boundary_aware_duration(scope, start_time, end_time, excluded_categories: [])
    base = scope.unscope(where: :time).with_valid_timestamps
    base = base.where.not("lower(category) IN (?)", excluded_categories) if excluded_categories.any?
    timeout = Heartbeat.heartbeat_timeout_duration.to_i
    start_time = time_value(start_time)
    end_time = time_value(end_time)
    window_start = start_time - timeout
    window_rows = base.where(time: window_start..end_time).sql(select: %w[id time])
    result = @client.select(<<~SQL.squish).first
      WITH diffs AS (
        SELECT time,
               least(greatest(time - lagInFrame(time, 1, time) OVER (
                 ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
               ), 0), #{timeout}) AS diff
        FROM (#{window_rows})
      )
      SELECT toInt64(round(COALESCE(sumIf(diff, time >= #{quote(start_time)}), 0))) AS duration,
             countIf(time < #{quote(start_time)}) AS preceding_count,
             countIf(time >= #{quote(start_time)}) AS selected_count
      FROM diffs
    SQL
    duration = result.fetch("duration").to_i
    return duration if result.fetch("preceding_count").to_i.positive? || result.fetch("selected_count").to_i.zero?

    has_older = @client.select(base.where(time: ...window_start).sql(select: [ "1" ], limit: 1)).any?
    has_older ? duration + timeout : duration
  end

  def daily_durations(scope, timezone:, start_time:, end_time:)
    timezone = "UTC" unless TZInfo::Timezone.all_identifiers.include?(timezone)
    day = "toDate(#{epoch_datetime('time', timezone)})"
    base = scope.where(time: start_time..end_time).with_valid_timestamps.sql(select: %w[id time])
    @client.select(<<~SQL.squish).map { |row| [ Date.iso8601(row.fetch("day")), row.fetch("duration").to_i ] }
      SELECT day, toInt64(round(COALESCE(sum(diff), 0))) AS duration
      FROM (
        SELECT #{day} AS day,
               least(greatest(time - lagInFrame(time, 1, time) OVER (
                 PARTITION BY #{day} ORDER BY time, id
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
               ), 0), #{Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
        FROM (#{base}) heartbeat_rows
      ) GROUP BY day ORDER BY day
    SQL
  end

  def daily_streaks(user_ids, start_date:, exclude_browser_time:)
    return {} if user_ids.empty?

    start_date = [ start_date, 31.days.ago ].max
    result = user_ids.index_with(0)
    users_by_timezone = user_ids.each_slice(QUERY_BATCH_SIZE).flat_map do |ids|
      User.where(id: ids).pluck(:id, :timezone)
    end.group_by do |_id, timezone|
      TZInfo::Timezone.all_identifiers.include?(timezone) ? timezone : "UTC"
    end
    users_by_timezone.each do |timezone, users|
      users.each_slice(QUERY_BATCH_SIZE) do |user_batch|
        ids = user_batch.map(&:first)
        day = "toDate(fromUnixTimestamp64Micro(toInt64(round(time * 1000000)), #{quote(timezone)}))"
        scope = all.where(user_id: ids).where.not(category: "browsing")
          .where(time: start_date..Time.current).with_valid_timestamps
        scope = scope.excluding_browser_time if exclude_browser_time
        base = scope.sql(select: %w[id user_id time])
        rows = @client.select(<<~SQL.squish).group_by { |row| row.fetch("user_id").to_i }
          SELECT user_id, day, toInt64(round(COALESCE(sum(diff), 0))) AS duration
          FROM (
            SELECT user_id, #{day} AS day,
                   least(greatest(time - lagInFrame(time, 1, time) OVER (
                     PARTITION BY user_id, #{day} ORDER BY time, id
                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                   ), 0), #{Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
            FROM (#{base}) heartbeat_rows
          ) GROUP BY user_id, day ORDER BY user_id, day DESC
        SQL
        rows.each do |user_id, days|
          current_date = Time.current.in_time_zone(timezone).to_date
          eligible = days.filter_map do |row|
            date = Date.iso8601(row.fetch("day"))
            date if date <= current_date && row.fetch("duration").to_i >= 15.minutes
          end
          expected = eligible.first == current_date ? current_date : current_date - 1.day
          streak = eligible.take_while.with_index { |date, index| date == expected - index.days }.length
          result[user_id] = streak
        end
      end
    end
    result
  end

  def spans(scope, timeout: Heartbeat.heartbeat_timeout_duration.to_i)
    times = pluck(scope.with_valid_timestamps, %i[time id], order: [ "time ASC", "id ASC" ])
    return [] if times.empty?

    spans = []
    start_time = times.first.first.to_f
    times.each_with_index do |(time, _id), index|
      current = time.to_f
      following = times[index + 1]&.first&.to_f
      next if following && following - current <= timeout

      gap = following ? [ following - current, timeout ].min : 0
      finish = current + gap
      duration = (finish - start_time).round
      spans << { start_time:, end_time: finish, duration: } if duration.positive?
      start_time = following if following
    end
    spans
  end

  def filter_options(scope, fields)
    select = fields.map do |field|
      validate_column!(field.to_s)
      column = identifier(field)
      "arraySort(groupUniqArrayIf(#{column}, #{column} IS NOT NULL AND notEmpty(trimBoth(#{column})))) AS #{identifier("#{field}_values")}"
    end
    row = @client.select(scope.sql(select:, order: [])).first
    fields.index_with { |field| row.fetch("#{field}_values", []) }
  end

  def project_details(scope)
    base = scope.with_valid_timestamps.where.not(project: [ nil, "" ])
      .sql(select: %w[id time project language])
    @client.select(<<~SQL.squish).to_h do |row|
      SELECT project, count() AS heartbeat_count, min(time) AS first_heartbeat,
             max(time) AS last_heartbeat,
             arraySort(groupUniqArrayIf(language, language IS NOT NULL AND notEmpty(trimBoth(language)))) AS languages,
             toInt64(round(COALESCE(sum(diff), 0))) AS duration
      FROM (
        SELECT project, time, language,
               least(greatest(time - lagInFrame(time, 1, time) OVER (
                 PARTITION BY project ORDER BY time, id
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
               ), 0), #{Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
        FROM (#{base}) project_heartbeats
      ) GROUP BY project
    SQL
      [
        row.fetch("project"),
        {
          total_seconds: row.fetch("duration").to_i,
          total_heartbeats: row.fetch("heartbeat_count").to_i,
          first_heartbeat: row.fetch("first_heartbeat").to_f,
          last_heartbeat: row.fetch("last_heartbeat").to_f,
          languages: row.fetch("languages")
        }
      ]
    end
  end

  def weekly_project_stats(scope, timezone:, ranges:)
    timezone = valid_timezone(timezone)
    result = ranges.to_h { |week_key, *_| [ week_key, {} ] }
    local_time = epoch_datetime("time", timezone)
    week = "toStartOfWeek(#{local_time}, 1)"
    base = scope.with_valid_timestamps.where(time: ranges.last[1]..ranges.first[2])
      .sql(select: %w[id time project])
    @client.select(<<~SQL.squish).each do |row|
      SELECT formatDateTime(week, '%F') AS week_key, project,
             toInt64(round(COALESCE(sum(diff), 0))) AS duration
      FROM (
        SELECT project, #{week} AS week,
               least(greatest(time - lagInFrame(time, 1, time) OVER (
                 PARTITION BY project, #{week} ORDER BY time, id
                 ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
               ), 0), #{Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
        FROM (#{base}) weekly_heartbeats
      ) GROUP BY week, project ORDER BY week DESC, project
    SQL
      result[row.fetch("week_key")][row["project"]] = row.fetch("duration").to_i
    end
    result
  end

  def today_stats(scope, timezone:)
    rows = @client.select(scope.today.distinct.sql(select: [
      "language",
      "editor",
      "count() OVER (PARTITION BY language) AS language_count",
      "count() OVER (PARTITION BY editor) AS editor_count"
    ], order: %w[language editor]))
    {
      timezone:,
      todays_duration_seconds: duration_seconds(scope.today),
      language_counts: rows.to_h { |row| [ row["language"], row.fetch("language_count").to_i ] },
      editor_counts: rows.to_h { |row| [ row["editor"], row.fetch("editor_count").to_i ] }
    }
  end

  def coding_rhythm(scope, timezone:)
    timezone = valid_timezone(timezone)
    local_time = epoch_datetime("time", timezone)
    base = scope.with_valid_timestamps.sql(select: %w[id time])
    rows = @client.select(<<~SQL.squish)
      SELECT weekday, hour, toInt64(round(COALESCE(sum(diff), 0))) AS duration
      FROM (
        SELECT toDayOfWeek(#{local_time}) AS weekday, toHour(#{local_time}) AS hour,
               least(greatest(time - lagInFrame(time, 1, time) OVER (
                 ORDER BY time, id ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
               ), 0), #{Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
        FROM (#{base}) rhythm_heartbeats
      ) GROUP BY weekday, hour ORDER BY weekday, hour
    SQL
    {
      timezone:,
      duration_by_slot: rows.to_h { |row| [ "#{row['weekday']}-#{row['hour']}", row.fetch("duration").to_i ] }
    }
  end

  def latest_direct_heartbeats(since:, coding_only: true, per_project: false)
    category_filter = coding_only ? "AND category = 'coding'" : ""
    project = per_project ? "project" : "tupleElement(argMax(tuple(project), tuple(time, id)), 1) AS project"
    grouping = per_project ? "user_id, project" : "user_id"
    @client.select(<<~SQL.squish)
      SELECT user_id, #{project}, max(time) AS latest_time,
             argMax(id, tuple(time, id)) AS latest_id
      FROM heartbeats_by_time FINAL
      WHERE deleted_at IS NULL AND source_type = #{SOURCE_TYPES.fetch('direct_entry')}
        #{category_filter} AND time_5m >= #{time_bucket(since)} AND time > #{quote(time_value(since))}
      GROUP BY #{grouping}
    SQL
  end

  def active_users_by_hour(since:, before:)
    hour = "intDiv(toInt64(round(time)), 3600) * 3600"
    @client.select(<<~SQL.squish).map do |row|
      SELECT #{epoch_datetime(hour, 'UTC')} AS hour, uniqExact(user_id) AS user_count
      FROM heartbeats_by_time FINAL
      WHERE deleted_at IS NULL AND category = 'coding' AND time >= 0 AND time <= #{VALID_TIME_MAX}
        AND time_5m >= #{time_bucket(since)} AND time_5m <= #{time_bucket(before)}
        AND time > #{quote(time_value(since))} AND time < #{quote(time_value(before))}
      GROUP BY hour ORDER BY hour DESC
    SQL
      { hour: Time.zone.parse(row.fetch("hour")), count: row.fetch("user_count").to_i }
    end
  end

  def latest_ip_by_user(user_ids)
    return {} if user_ids.empty?

    rows = user_ids.map { |id| Integer(id) }.uniq.each_slice(QUERY_BATCH_SIZE).flat_map do |ids|
      @client.select(<<~SQL.squish)
        SELECT user_id, argMax(ip_address, id) AS latest_ip_address
        FROM heartbeats FINAL
        WHERE deleted_at IS NULL AND ip_address IS NOT NULL
          AND user_id IN (#{ids.map { |id| quote(id) }.join(', ')})
        GROUP BY user_id
      SQL
    end
    rows.to_h { |row| [ row.fetch("user_id").to_i, row.fetch("latest_ip_address") ] }
  end

  def project_durations_by_user(user_ids)
    return {} if user_ids.empty?

    user_ids.map { |id| Integer(id) }.uniq.each_slice(QUERY_BATCH_SIZE).each_with_object({}) do |ids, result|
      rows = @client.select(<<~SQL.squish)
        SELECT user_id, project, toInt64(round(COALESCE(sum(diff), 0))) AS duration
        FROM (
          SELECT user_id, project,
                 least(greatest(time - lagInFrame(time, 1, time) OVER (
                   PARTITION BY user_id, project ORDER BY time, id
                   ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                 ), 0), #{Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
          FROM heartbeats FINAL
          WHERE deleted_at IS NULL AND project IS NOT NULL
            AND time >= 0 AND time <= #{VALID_TIME_MAX}
            AND user_id IN (#{ids.join(', ')})
        ) GROUP BY user_id, project
      SQL
      rows.each do |row|
        result[row.fetch("user_id").to_i] ||= {}
        result[row.fetch("user_id").to_i][row.fetch("project")] = row.fetch("duration").to_i
      end
    end
  end

  def ip_machine_pairs(since:, limit:, inclusive: false)
    time_operator = inclusive ? ">=" : ">"
    @client.select(<<~SQL.squish)
      WITH combinations AS (
        SELECT user_id, machine, ip_address, min(time) AS first_seen, max(time) AS last_seen
        FROM heartbeats_by_time FINAL
        WHERE deleted_at IS NULL AND machine IS NOT NULL AND ip_address IS NOT NULL
          AND time_5m >= #{time_bucket(since)} AND time #{time_operator} #{quote(time_value(since))}
        GROUP BY user_id, machine, ip_address
      )
      SELECT a.user_id AS user_a_id, b.user_id AS user_b_id, a.machine, a.ip_address,
             a.first_seen AS user_a_first_seen, a.last_seen AS user_a_last_seen,
             b.first_seen AS user_b_first_seen, b.last_seen AS user_b_last_seen
      FROM combinations a INNER JOIN combinations b
        ON a.machine = b.machine AND a.ip_address = b.ip_address
      WHERE a.user_id < b.user_id
      ORDER BY a.user_id, b.user_id, a.machine, a.ip_address
      LIMIT #{Integer(limit)}
    SQL
  end

  def shared_machines(since:, limit:)
    rows = @client.select(<<~SQL.squish)
      SELECT machine, uniqExact(user_id) AS machine_frequency,
             arraySort(groupUniqArray(user_id)) AS user_ids
      FROM heartbeats_by_time FINAL
      WHERE deleted_at IS NULL AND machine IS NOT NULL
        AND time_5m >= #{time_bucket(since)} AND time > #{quote(time_value(since))}
      GROUP BY machine HAVING machine_frequency > 1
      ORDER BY machine_frequency DESC, machine ASC
      LIMIT #{Integer(limit)}
    SQL
    existing_ids = User.where(id: rows.flat_map { |row| row.fetch("user_ids") }).pluck(:id).to_set
    rows.map do |row|
      ids = row.fetch("user_ids").map(&:to_i).select { |id| existing_ids.include?(id) }
      row.merge("user_ids" => ids)
    end
  end

  def visualization(user_id:, start_time:, end_time:)
    scope = for_user(user_id).where(time: start_time..end_time)
    points = pluck(scope, %i[time lineno cursorpos], order: [ "time ASC", "id ASC" ], limit: 1_000_000)
    grouped = points.group_by { |time, _lineno, _cursorpos| Time.at(time.to_f).utc.to_date }
    quantized = grouped.transform_values do |day_points|
      max_lineno = [ day_points.filter_map { |_time, lineno, _cursor| lineno }.max.to_i, 1 ].max
      max_cursor = [ day_points.filter_map { |_time, _lineno, cursor| cursor }.max.to_i, 1 ].max
      selected = {}
      seen_lineno = Set.new
      seen_cursor = Set.new
      seen_empty = Set.new
      day_points.each do |time, lineno, cursorpos|
        seconds = time.to_f % 1.day
        qx = (2 + (seconds / 1.day) * 396).round
        lineno_key = [ qx, (2 + (1 - lineno.to_f / max_lineno) * 96).round ] if lineno
        cursor_key = [ qx, (2 + (1 - cursorpos.to_f / max_cursor) * 96).round ] if cursorpos
        empty_key = qx unless lineno || cursorpos
        new_lineno = seen_lineno.add?(lineno_key) if lineno_key
        new_cursor = seen_cursor.add?(cursor_key) if cursor_key
        new_empty = seen_empty.add?(empty_key) if empty_key
        keep = new_lineno || new_cursor || new_empty
        selected[[ time, lineno, cursorpos ]] = { time:, lineno:, cursorpos: } if keep
      end
      selected.values.sort_by { |point| point.fetch(:time) }
    end
    { points_by_day: quantized, daily_totals: daily_durations(scope, timezone: "UTC", start_time:, end_time:).to_h }
  end

  def normalized_user_stats(scope)
    normalized = "if(time > 1000000000000, time / 1000, time)"
    valid = scope.where("#{normalized} BETWEEN ? AND ?", Time.utc(2000, 1, 1).to_i, Time.utc(2100, 1, 1).to_i)
    row = @client.select(valid.sql(select: [
      "count() AS total_heartbeats",
      "maxOrNull(time) AS last_heartbeat_at",
      "uniqExactIf(language, language IS NOT NULL) AS languages_used",
      "uniqExactIf(project, project IS NOT NULL) AS projects_worked_on",
      "uniqExact(toDate(#{epoch_datetime(normalized, 'UTC')})) AS days_active"
    ])).first
    row.transform_values!.with_index do |value, index|
      if index == 1
        timestamp = value&.to_f
        timestamp && timestamp > 1_000_000_000_000 ? timestamp / 1_000 : timestamp
      else
        value.to_i
      end
    end
    row["total_coding_time"] = duration_seconds(valid)
    row
  end

  def project_stats(scope)
    rows = @client.select(scope.where.not(project: nil).sql(
      select: [
        "project",
        "count() AS heartbeat_count",
        "min(time) AS first_heartbeat",
        "max(time) AS last_heartbeat",
        "arraySort(groupUniqArrayIf(language, language IS NOT NULL)) AS languages"
      ],
      group: [ "project" ],
      order: [ "heartbeat_count DESC" ]
    ))
    durations = duration_seconds(scope.where.not(project: nil).group(:project))
    rows.map { |row| row.merge("duration" => durations[row.fetch("project")].to_i) }
  end

  def active_days_count(scope, timezone:)
    local_date = "toDate(#{epoch_datetime('time', timezone)})"
    aggregate(scope.where.not(time: nil), "uniqExact(#{local_date})").to_i
  end

  def home_stats(archived_projects: [])
    exclusions = archived_projects.map do |user_id, project|
      "(#{quote(Integer(user_id))}, #{quote(project.to_s)})"
    end
    archive_filter = if exclusions.empty?
      ""
    else
      "AND (user_id, ifNull(project, '')) NOT IN (#{exclusions.join(', ')})"
    end
    row = @client.select(<<~SQL.squish).first
      SELECT countIf(total_seconds > 0) AS users_tracked,
             toInt64(round(COALESCE(sum(total_seconds), 0))) AS seconds_tracked
      FROM (
        SELECT user_id, COALESCE(sum(diff), 0) AS total_seconds
        FROM (
          SELECT user_id,
                 least(greatest(time - lagInFrame(time, 1, time) OVER (
                   PARTITION BY user_id ORDER BY time, id
                   ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
                 ), 0), #{Heartbeat.heartbeat_timeout_duration.to_i}) AS diff
          FROM heartbeats FINAL
          WHERE deleted_at IS NULL AND time >= 0 AND time <= #{VALID_TIME_MAX}
            #{archive_filter}
        ) GROUP BY user_id
      )
    SQL
    {
      users_tracked: row.fetch("users_tracked").to_i,
      seconds_tracked: row.fetch("seconds_tracked").to_i
    }
  end

  def persist(user_id:, records:)
    outcomes = nil
    with_clickhouse_timeouts(timeout: INGEST_TIMEOUT, retry_limit: INGEST_INSERT_RETRY_LIMIT) do
      ActiveRecord::Base.transaction do
        ensure_user_accepts_heartbeats!(user_id)
        records.filter_map { |record| record.stringify_keys["ja4_id"] }.uniq.sort.each do |ja4_id|
          lock_ja4_changes(ja4_id)
          raise ActiveRecord::RecordNotFound, "JA4 was deleted during heartbeat ingestion" unless Ja4.exists?(ja4_id)
        end

        outcomes = persist_records(user_id, records)

        deliver_store_rows(outcomes.pluck(:row).uniq { |row| [ row.fetch("user_id"), row.fetch("id") ] })
      end
    end
    outcomes
  rescue
    HeartbeatDeliveryJob.perform_later(user_id)
    raise
  end

  def backfill(records)
    serialized = records.map do |heartbeat|
      row = serialize_attributes(heartbeat.attributes)
      old_hash = row.fetch("fields_hash")
      row.merge("fields_hash" => canonical_fields_hash(heartbeat.attributes), "alias_hashes" => [ old_hash ])
    end
    existing = store_rows_by_keys(serialized.map { |row| [ row.fetch("user_id"), row.fetch("id") ] })
    existing_by_id = existing.index_by { |row| row.fetch("id").to_i }
    serialized.each do |row|
      current = existing_by_id[row.fetch("id").to_i]
      next unless current

      matches = current.fetch("user_id").to_i == row.fetch("user_id").to_i &&
        current.fetch("time").to_f == row.fetch("time").to_f &&
        current.fetch("fields_hash") == row.fetch("fields_hash")
      raise "Heartbeat identity collision for ID #{row.fetch('id')}" unless matches
    end

    missing_records = serialized.reject { |row| existing_by_id.key?(row.fetch("id").to_i) }
    version = next_version if missing_records.any?
    store_version = next_version if missing_records.any?
    missing = missing_records.map do |row|
      build_store_row(row, id: row.fetch("id"), version:, store_version:, canonicalized: true)
    end
    insert_store_rows(missing)
    write_aliases_for_rows(existing + missing)
    deliver_store_rows(missing)
    serialized.length
  end

  def serialize_attributes(attributes)
    attributes.stringify_keys.slice(*IDENTITY_COLUMNS).transform_values do |value|
      case value
      when Time, DateTime then value.utc.strftime("%Y-%m-%d %H:%M:%S.%6N")
      when IPAddr then value.to_s
      else value
      end
    end.tap do |record|
      record["source_type"] = SOURCE_TYPES.fetch(record.fetch("source_type").to_s, record["source_type"])
      record["ysws_program"] ||= 0
      record["dependencies_is_null"] = record["dependencies"].nil?
      record["dependencies_json"] = nil
      if record["dependencies"].is_a?(Array) && record["dependencies"].any? { |dependency| !dependency.is_a?(String) }
        record["dependencies_json"] = JSON.generate(record["dependencies"])
        record["dependencies"] = []
      end
      record["dependencies"] ||= []
    end
  end

  def prepare_transfer(from_user_id:, to_user_id:)
    raise ArgumentError, "Cannot transfer heartbeats to the same user" if from_user_id == to_user_id
    self.class.ensure_writes_enabled!
    self.class.ensure_mutations_enabled!

    [ from_user_id, to_user_id ].sort.each { |user_id| lock_user_writes(user_id) }
    blocked = HeartbeatDeletion.where(user_id: [ from_user_id, to_user_id ]).exists? ||
      pending_transfer?(from_user_id) || pending_transfer?(to_user_id)
    raise "A heartbeat operation is already recorded for one of these users" if blocked

    HeartbeatTransfer.create!(from_user_id:, to_user_id:, heartbeat_count: 0)
  end

  def prepare_deletion(user_id)
    self.class.ensure_writes_enabled!
    self.class.ensure_mutations_enabled!
    lock_user_writes(user_id)
    if pending_transfer?(user_id)
      raise "A heartbeat operation is already recorded for this user"
    end

    HeartbeatDeletion.find_or_create_by!(user_id:)
  end

  def prepare_ja4_nullification(ja4_id)
    self.class.ensure_writes_enabled!
    self.class.ensure_mutations_enabled!
    lock_ja4_changes(ja4_id)
    HeartbeatJa4Nullification.find_or_create_by!(ja4_id:)
  end

  def transfer_rows(transfer, reconcile_nullifications: true)
    self.class.ensure_mutations_enabled!
    with_mutation_timeouts do
      lock_user_ids = [ transfer.from_user_id, transfer.to_user_id ].sort
      canonicalize_user_store(transfer.to_user_id, deliver: false, lock_user_ids:) { nil }
      canonicalize_user_store(transfer.from_user_id, deliver: false, lock_user_ids:) do |source_rows|
        transfer_batch(transfer, source_rows)
      end
      transfer.update!(copied_at: Time.current) unless transfer.copied_at?
      if reconcile_nullifications
        reconcile_user_nullifications([ transfer.from_user_id, transfer.to_user_id ], allow_transfer: true)
      end
    end
  end

  def soft_delete_user(user_id, version: nil, deleted_at: Time.current, nullifications_through: nil)
    self.class.ensure_mutations_enabled!
    version ||= next_version
    with_mutation_timeouts do
      after_id = 0
      loop do
        finished = false
        ActiveRecord::Base.transaction do
          lock_user_writes(user_id)
          raise "Heartbeat transfer is pending for user #{user_id}" if pending_transfer?(user_id)

          rows = store_rows_for_user(user_id, after_id:, limit: QUERY_BATCH_SIZE)
          if rows.empty?
            finished = true
            next
          end

          nullifications = HeartbeatJa4Nullification.where(
            ja4_id: rows.filter_map { |row| row["ja4_id"] }.uniq
          )
          if nullifications_through
            nullifications = nullifications.where(clickhouse_version: ..Integer(nullifications_through))
          end
          nullified_ja4_ids = nullifications.pluck(:ja4_id).to_set
          pending, canonical = rows.partition { |row| !row.fetch("canonicalized") }
          store_version = next_version
          insert_store_rows(pending.map do |row|
            attributes = {
              "canonicalized" => true,
              "duplicate_of" => 0,
              "deleted_at" => serialized_time(deleted_at),
              "version" => [ row.fetch("version").to_i, Integer(version) ].max
            }
            attributes["ja4_id"] = nil if nullified_ja4_ids.include?(row["ja4_id"].to_i)
            replace_store_row(row, attributes, store_version:)
          end)
          replacements = canonical.filter_map do |row|
            next if row["duplicate_of"]
            attributes = { "deleted_at" => serialized_time(deleted_at) }
            attributes["ja4_id"] = nil if nullified_ja4_ids.include?(row["ja4_id"].to_i)
            transition_store_row(
              row,
              version:,
              attributes:,
              store_version:
            )
          end
          insert_store_rows(changed_store_rows(replacements, rows))
          write_aliases_for_rows(replacements)
          deliver_store_rows(replacements)
          after_id = rows.last.fetch("id").to_i
        end
        break if finished
      end
    end
  end

  def change_deleted(heartbeat_id:, user_id:, deleted:)
    self.class.ensure_writes_enabled!
    self.class.ensure_mutations_enabled!
    with_mutation_timeouts do
      ActiveRecord::Base.transaction do
        ensure_user_accepts_heartbeats!(user_id)
        reconcile_user_nullifications([ user_id ])
        record = current_store_row(user_id, heartbeat_id)
        aliases = identity_hashes(record)
        if !deleted
          conflicts = alias_rows(user_id, aliases).select do |row|
            row.fetch("active") && row.fetch("heartbeat_id").to_i != heartbeat_id.to_i
          end
          raise ActiveRecord::RecordNotUnique, "A heartbeat with this identity already exists" if conflicts.any?
        end
        deleted_at = deleted ? Time.current : nil
        replacement = transition_store_row(
          record,
          version: next_version,
          attributes: { "deleted_at" => deleted_at && serialized_time(deleted_at) }
        )
        insert_store_rows(changed_store_rows([ replacement ], [ record ]))
        write_aliases(replacement, active: !deleted)
        deliver_store_rows([ replacement ])
      end
    end
  rescue
    HeartbeatDeliveryJob.perform_later(user_id)
    raise
  end

  def nullify_ja4(ja4_id, version:, allow_transfer: false, user_ids: nil, superseded_deletion: :raise)
    with_mutation_timeouts do
      perform_ja4_nullification(
        ja4_id,
        version:,
        allow_transfer:,
        user_ids:,
        superseded_deletion:
      )
    end
  end

  def perform_ja4_nullification(ja4_id, version:, allow_transfer:, user_ids:, superseded_deletion:)
    self.class.ensure_mutations_enabled!
    unless %i[raise skip].include?(superseded_deletion)
      raise ArgumentError, "Unknown superseded deletion behavior: #{superseded_deletion}"
    end

    operation_rows = store_rows_for_ja4(ja4_id) + store_rows(
      "ja4_nullification_version = #{quote(version)} AND duplicate_of IS NULL AND " \
        "(heartbeats_version < version OR heartbeats_by_time_version < version)",
      order: "user_id, id"
    )
    if user_ids
      allowed = user_ids.map(&:to_i).to_set
      operation_rows.select! { |row| allowed.include?(row.fetch("user_id").to_i) }
    end
    operation_rows.uniq { |row| [ row.fetch("user_id"), row.fetch("id") ] }
      .group_by { |row| row.fetch("user_id").to_i }.each do |user_id, _rows|
      ActiveRecord::Base.transaction do
        lock_user_writes(user_id)
        lock_ja4_changes(ja4_id)
        if !allow_transfer && pending_transfer?(user_id)
          raise "Heartbeat transfer is pending for user #{user_id}"
        end
        deletion = HeartbeatDeletion.find_by(user_id:)
        raise "Heartbeat deletion is pending for user #{user_id}" if deletion && !deletion.completed?
        if deletion && deletion.clickhouse_version > version
          next if superseded_deletion == :skip

          raise "Heartbeat deletion version supersedes JA4 nullification for user #{user_id}"
        end

        rows = operation_rows.select { |row| row.fetch("user_id").to_i == user_id }
        pending, canonical = rows.partition { |row| !row.fetch("canonicalized") }
        insert_store_rows(pending.map do |row|
          replace_store_row(row, { "ja4_id" => nil, "ja4_nullification_version" => Integer(version) })
        end)
        replacements = canonical.filter_map do |row|
          next if row["duplicate_of"]
          replacement_version = if row["ja4_id"].nil? || row.fetch("version").to_i < Integer(version)
            version
          else
            next_version
          end
          replacement = transition_store_row(
            row,
            version: replacement_version,
            attributes: { "ja4_id" => nil }
          )
          if replacement.fetch("ja4_nullification_version").to_i < Integer(version)
            replacement = replace_store_row(replacement, { "ja4_nullification_version" => Integer(version) })
          end
          replacement
        end
        insert_store_rows(changed_store_rows(replacements, canonical))
        deliver_store_rows(replacements)
      end
    end
  end

  def lock_user_writes(user_id)
    connection = ActiveRecord::Base.connection
    connection.raw_connection.exec_params(
      "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      [ user_lock_key(user_id) ]
    )
  end

  def lock_ja4_changes(ja4_id)
    connection = ActiveRecord::Base.connection
    connection.raw_connection.exec_params(
      "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
      [ "heartbeat-ja4:#{Integer(ja4_id)}" ]
    )
  end

  def ensure_user_accepts_heartbeats!(user_id)
    lock_user_writes(user_id)
    blocked = !User.exists?(user_id) ||
      HeartbeatTransfer.exists?(from_user_id: user_id) ||
      pending_transfer?(user_id) ||
      HeartbeatDeletion.exists?(user_id:)
    raise ActiveRecord::RecordNotFound, "User is not accepting heartbeats" if blocked
  end

  def next_version
    next_versions(1).sole
  end

  def next_versions(count)
    next_sequence_values("heartbeat_clickhouse_versions_id_seq", count)
  end

  def next_id
    next_ids(1).sole
  end

  def next_ids(count)
    next_sequence_values("heartbeat_id_allocations_id_seq", count)
  end

  def reseed_postgres_sequences!
    store_watermarks = @client.select(<<~SQL.squish).sole
      SELECT max(id) AS max_id,
             greatest(
               max(version), max(store_version), max(ja4_nullification_version),
               max(heartbeats_version), max(heartbeats_by_time_version)
             ) AS max_version
      FROM heartbeat_store
    SQL
    alias_watermarks = @client.select(<<~SQL.squish).sole
      SELECT max(heartbeat_id) AS max_id, max(alias_version) AS max_version
      FROM heartbeat_aliases
    SQL
    control_version = [
      HeartbeatTransfer.maximum(:copy_version),
      HeartbeatTransfer.maximum(:delete_version),
      HeartbeatDeletion.maximum(:clickhouse_version),
      HeartbeatJa4Nullification.maximum(:clickhouse_version)
    ].compact.max.to_i

    watermarks = {
      "heartbeat_id_allocations_id_seq" => [
        store_watermarks.fetch("max_id").to_i,
        alias_watermarks.fetch("max_id").to_i
      ].max,
      "heartbeat_clickhouse_versions_id_seq" => [
        store_watermarks.fetch("max_version").to_i,
        alias_watermarks.fetch("max_version").to_i,
        control_version
      ].max
    }
    watermarks.to_h do |sequence, watermark|
      result = ActiveRecord::Base.connection.raw_connection.exec_params(<<~SQL.squish, [ sequence, watermark ])
        SELECT setval(
          $1::regclass,
          GREATEST(COALESCE(pg_sequence_last_value($1::regclass), 1), $2::bigint),
          true
        )
      SQL
      [ sequence, result.getvalue(0, 0).to_i ]
    end
  end

  private def next_sequence_values(sequence, count)
    count = Integer(count)
    return [] if count.zero?

    ActiveRecord::Base.uncached do
      ActiveRecord::Base.connection.raw_connection.exec_params(
        "SELECT nextval($1::regclass) FROM generate_series(1, $2)",
        [ sequence, count ]
      ).column_values(0).map!(&:to_i)
    end
  end

  def reconcile_store(limit: 1_000, user_id: nil)
    with_mutation_timeouts { reconcile_store_rows(limit:, user_id:) }
  end

  def reconcile_store_rows(limit:, user_id:)
    conditions = [
      "canonicalized = false OR (canonicalized = true AND duplicate_of IS NULL AND " \
        "(heartbeats_version < version OR heartbeats_by_time_version < version))"
    ]
    conditions.unshift("user_id = #{quote(Integer(user_id))}") if user_id
    rows = @client.select(<<~SQL.squish)
      SELECT #{STORE_COLUMNS.join(', ')} FROM heartbeat_store FINAL
      WHERE (#{conditions.join(') AND (')})
      ORDER BY store_version LIMIT #{Integer(limit)}
    SQL
    rows.group_by { |row| row.fetch("user_id").to_i }.each do |user_id, candidates|
      if transfer = HeartbeatTransfer.find_by(from_user_id: user_id)
        transfer_rows(transfer)
        next
      end
      if deletion = HeartbeatDeletion.find_by(user_id:)
        soft_delete_user(user_id, version: deletion.clickhouse_version, deleted_at: deletion.created_at)
        next
      end
      reconcile_user_nullifications([ user_id ])

      ActiveRecord::Base.transaction do
        lock_user_writes(user_id)
        next if pending_transfer?(user_id)

        current = candidates.filter_map do |candidate|
          row = current_store_row(user_id, candidate.fetch("id"), required: false)
          next unless row
          next activate_candidate(row) unless row.fetch("canonicalized")
          next if row["duplicate_of"]

          write_aliases(row, active: row["deleted_at"].nil?)
          row
        end
        deliver_store_rows(current)
      end
    end
    rows.length
  end

  def deliver_store_rows(rows)
    current = rows.index_by { |row| [ row.fetch("user_id").to_i, row.fetch("id").to_i ] }
    acknowledgements = Hash.new { |hash, key| hash[key] = {} }
    QUERY_LAYOUTS.each do |table, acknowledgement|
      pending = current.values.select do |row|
        row.fetch("canonicalized") && row["duplicate_of"].nil? &&
          row.fetch(acknowledgement).to_i < row.fetch("version").to_i
      end
      next if pending.empty?

      query_rows = pending.map { |row| row.slice(*STORAGE_COLUMNS) }
      insert_rows(table, query_rows)
      verify_visible_versions!(table, pending)
      pending.each do |row|
        key = [ row.fetch("user_id").to_i, row.fetch("id").to_i ]
        acknowledgements[key][acknowledgement] = row.fetch("version").to_i
      end
    end

    store_version = next_version if acknowledgements.any?
    acknowledged = acknowledgements.map do |key, values|
      replace_store_row(current.fetch(key), values, store_version:)
    end
    insert_store_rows(acknowledged)
    acknowledged.each do |row|
      current[[ row.fetch("user_id").to_i, row.fetch("id").to_i ]] = row
    end
    current.values
  end

  def build_store_row(record, id: next_id, version: next_version, store_version: next_version, canonicalized: false)
    values = STORAGE_COLUMNS.index_with { nil }.merge(record.stringify_keys.slice(*STORAGE_COLUMNS)).merge(
      "id" => Integer(id),
      "user_id" => Integer(record.stringify_keys.fetch("user_id")),
      "version" => version,
      "dependencies" => record.stringify_keys["dependencies"] || [],
      "dependencies_is_null" => record.stringify_keys.fetch("dependencies_is_null", false),
      "ysws_program" => record.stringify_keys.fetch("ysws_program", 0)
    )
    values.merge(
      "fields_hash" => record.stringify_keys.fetch("fields_hash"),
      "alias_hashes" => Array(record.stringify_keys["alias_hashes"]).compact.uniq,
      "payload_hash" => payload_hash(values),
      "canonicalized" => canonicalized,
      "duplicate_of" => nil,
      "ja4_nullification_version" => 0,
      "heartbeats_version" => 0,
      "heartbeats_by_time_version" => 0,
      "store_version" => store_version
    ).slice(*STORE_COLUMNS)
  end

  def persist_record(user_id, record)
    serialized = serialize_attributes(record).merge(
      "fields_hash" => record.stringify_keys.fetch("fields_hash"),
      "alias_hashes" => Array(record.stringify_keys["alias_hashes"]).compact.uniq
    )
    hashes = identity_hashes(serialized)
    aliases = alias_rows(user_id, hashes)
    winner_ids = aliases.pluck("heartbeat_id").map(&:to_i).uniq
    raise "Heartbeat aliases point to multiple identities" if winner_ids.many?

    if winner_ids.one?
      winner = current_store_row(user_id, winner_ids.sole)
      write_aliases(winner, active: winner["deleted_at"].nil?, hashes:)
      return { row: winner, inserted: false }
    end

    candidates = store_rows_for_aliases(user_id, hashes)
    candidate_winners = candidates.filter_map do |candidate|
      candidate["duplicate_of"]&.to_i || (candidate.fetch("id").to_i if candidate.fetch("canonicalized"))
    end.uniq
    raise "Heartbeat store hashes point to multiple identities" if candidate_winners.many?

    candidate = candidates.min_by { |row| row.fetch("id").to_i }
    inserted = candidate.nil?
    unless candidate
      candidate = build_store_row(serialized.merge("user_id" => user_id))
      insert_store_rows([ candidate ])
    end
    winner = activate_candidate(candidate, hashes:)
    { row: winner, inserted: inserted && winner.fetch("id").to_i == candidate.fetch("id").to_i }
  end

  def persist_records(user_id, records)
    serialized = records.map do |record|
      serialize_attributes(record).merge(
        "fields_hash" => record.stringify_keys.fetch("fields_hash"),
        "alias_hashes" => Array(record.stringify_keys["alias_hashes"]).compact.uniq,
        "user_id" => user_id
      )
    end
    hashes = serialized.flat_map { |record| identity_hashes(record) }
    if hashes.uniq.length == hashes.length && !stored_identities?(user_id, hashes)
      ids = next_ids(serialized.length)
      version, store_version, alias_version = next_versions(3)
      rows = serialized.each_with_index.map do |record, index|
        build_store_row(record, id: ids.fetch(index), version:, store_version:, canonicalized: true)
      end
      insert_store_rows(rows)
      insert_new_aliases(rows, version: alias_version)
      return rows.map { |row| { row:, inserted: true } }
    end

    records.map { |record| persist_record(user_id, record) }
  end

  def insert_new_aliases(rows, version: next_version)
    updated_at = serialized_time(Time.current)
    records = rows.flat_map do |row|
      identity_hashes(row).map do |fields_hash|
        {
          "user_id" => row.fetch("user_id").to_i,
          "fields_hash" => fields_hash,
          "heartbeat_id" => row.fetch("id").to_i,
          "active" => row["deleted_at"].nil?,
          "alias_version" => version,
          "updated_at" => updated_at
        }
      end
    end
    insert_rows("heartbeat_aliases", records)
  end

  def replace_store_row(row, replacements, store_version: nil)
    replacement = row.stringify_keys.slice(*STORE_COLUMNS).merge(replacements.stringify_keys)
    replacement["store_version"] = store_version || next_version
    replacement["payload_hash"] = payload_hash(replacement)
    replacement.slice(*STORE_COLUMNS)
  end

  def transition_store_row(row, version:, attributes:, store_version: nil)
    version = Integer(version)
    attributes = attributes.stringify_keys
    current_version = row.fetch("version").to_i
    expected = row.stringify_keys.slice(*STORE_COLUMNS).merge(attributes).merge("version" => version)
    expected["payload_hash"] = payload_hash(expected)

    if current_version > version
      matches = attributes.all? { |column, value| row[column] == value }
      raise "Heartbeat #{row.fetch('id')} has a newer conflicting version" unless matches
      return row
    end
    if current_version == version
      raise "Heartbeat #{row.fetch('id')} has conflicting payloads at version #{version}" unless
        row.fetch("payload_hash") == expected.fetch("payload_hash")
      return row
    end

    replace_store_row(
      row,
      attributes.merge(
        "version" => version,
        "heartbeats_version" => 0,
        "heartbeats_by_time_version" => 0
      ),
      store_version:
    )
  end

  def changed_store_rows(rows, previous_rows)
    versions = previous_rows.index_by { |row| [ row.fetch("user_id").to_i, row.fetch("id").to_i ] }
      .transform_values { |row| row.fetch("store_version").to_i }
    rows.reject do |row|
      versions[[ row.fetch("user_id").to_i, row.fetch("id").to_i ]] == row.fetch("store_version").to_i
    end
  end

  def canonicalize_user_store(user_id, deliver: true, lock_user_ids: [ user_id ])
    after_id = 0
    loop do
      finished = false
      ActiveRecord::Base.transaction do
        lock_user_ids.each { |locked_user_id| lock_user_writes(locked_user_id) }
        rows = store_rows_for_user(user_id, after_id:, limit: QUERY_BATCH_SIZE)
        if rows.empty?
          finished = true
          next
        end

        current = rows.map do |row|
          row.fetch("canonicalized") ? row : activate_candidate(row)
        end.reject { |row| row["duplicate_of"] }
          .uniq { |row| [ row.fetch("user_id").to_i, row.fetch("id").to_i ] }
        write_aliases_for_rows(current)
        current = deliver_store_rows(current) if deliver
        yield current
        after_id = rows.last.fetch("id").to_i
      end
      break if finished
    end
  end

  def transfer_batch(transfer, source_rows)
    hashes = source_rows.flat_map { |row| identity_hashes(row) }.uniq
    target_ids_by_hash = alias_rows(transfer.to_user_id, hashes)
      .to_h { |row| [ row.fetch("fields_hash"), row.fetch("heartbeat_id").to_i ] }
    target_ids = source_rows.pluck("id").map(&:to_i) + target_ids_by_hash.values
    targets_by_id = store_rows_for_user_ids(transfer.to_user_id, target_ids.uniq)
      .index_by { |row| row.fetch("id").to_i }
    target_rows = []
    tombstones = []
    store_writes = []
    store_version = next_version
    source_rows.each do |row|
      if row.fetch("version").to_i >= transfer.delete_version && row["deleted_at"] == serialized_time(transfer.created_at)
        target = transferred_target(row, transfer, targets_by_id:, target_ids_by_hash:)
        validate_transferred_row!(source: row, target:, transfer:)
        target_rows << target
        tombstones << row
        next
      end
      if row.fetch("version").to_i >= transfer.delete_version
        raise "Heartbeat #{row.fetch('id')} supersedes transfer #{transfer.id}"
      end

      target = replace_store_row(
        row,
        {
          "user_id" => transfer.to_user_id,
          "version" => transfer.copy_version,
          "heartbeats_version" => 0,
          "heartbeats_by_time_version" => 0
        },
        store_version:
      )
      tombstone = replace_store_row(
        row,
        {
          "deleted_at" => serialized_time(transfer.created_at),
          "version" => transfer.delete_version,
          "heartbeats_version" => 0,
          "heartbeats_by_time_version" => 0
        },
        store_version:
      )
      existing_target = transferred_target(row, transfer, targets_by_id:, target_ids_by_hash:)
      if existing_target
        validate_transferred_row!(source: row, target: existing_target, transfer:)
        target = if row["deleted_at"].nil? && existing_target["deleted_at"]
          transition_store_row(
            existing_target,
            version: transfer.copy_version,
            attributes: { "deleted_at" => nil },
            store_version:
          )
        else
          existing_target
        end
      end
      store_writes << target unless existing_target && target.equal?(existing_target)
      store_writes << tombstone
      target_rows << target
      tombstones << tombstone
    end
    insert_store_rows(store_writes)
    write_aliases_for_rows(target_rows + tombstones)
    deliver_store_rows(target_rows + tombstones)
  end

  def validate_transferred_row!(source:, target:, transfer:)
    raise "Transferred heartbeat #{source.fetch('id')} has no target" unless target
    if source.fetch("id").to_i != target.fetch("id").to_i
      winner_ids = alias_rows(transfer.to_user_id, identity_hashes(source))
        .pluck("heartbeat_id").map(&:to_i).uniq
      raise "Transferred heartbeat #{source.fetch('id')} has a conflicting target" unless
        winner_ids == [ target.fetch("id").to_i ]
      return
    end

    raise "Transferred heartbeat #{source.fetch('id')} has the wrong target version" unless
      target.fetch("version").to_i >= transfer.copy_version
    raise "Transferred heartbeat #{source.fetch('id')} has a different identity" unless
      source.fetch("fields_hash") == target.fetch("fields_hash")

    unchanged = STORAGE_COLUMNS - %w[user_id ja4_id deleted_at version]
    matches = unchanged.all? { |column| source[column] == target[column] }
    raise "Transferred heartbeat #{source.fetch('id')} conflicts with its target" unless matches
  end

  def transferred_target(source, transfer, targets_by_id: nil, target_ids_by_hash: nil)
    by_id = if targets_by_id
      targets_by_id[source.fetch("id").to_i]
    else
      current_store_row(transfer.to_user_id, source.fetch("id"), required: false)
    end
    alias_ids = if target_ids_by_hash
      identity_hashes(source).filter_map { |hash| target_ids_by_hash[hash] }.uniq
    else
      alias_rows(transfer.to_user_id, identity_hashes(source)).pluck("heartbeat_id").map(&:to_i).uniq
    end
    raise "Heartbeat aliases point to multiple transfer targets" if alias_ids.many?

    by_alias = if alias_ids.one?
      targets_by_id ? targets_by_id[alias_ids.sole] :
        current_store_row(transfer.to_user_id, alias_ids.sole, required: false)
    end
    if by_id && by_alias && by_id.fetch("id").to_i != by_alias.fetch("id").to_i
      raise "Transferred heartbeat #{source.fetch('id')} has conflicting target identities"
    end
    by_id || by_alias
  end

  def verify_visible_versions!(table, rows)
    visible = rows.each_slice(QUERY_BATCH_SIZE).flat_map do |batch|
      tuples = batch.map do |row|
        second = row.fetch("time").to_f.floor
        bucket = five_minute_bucket(row.fetch("time"))
        if table == "heartbeats"
          "(#{quote(row.fetch('user_id'))}, #{bucket}, #{second}, #{quote(row.fetch('time'))}, #{quote(row.fetch('id'))})"
        else
          "(#{bucket}, #{second}, #{quote(row.fetch('user_id'))}, #{quote(row.fetch('time'))}, #{quote(row.fetch('id'))})"
        end
      end
      key = table == "heartbeats" ?
        "(user_id, time_5m, time_second, time, id)" :
        "(time_5m, time_second, user_id, time, id)"
      @client.select(<<~SQL.squish)
        SELECT user_id, id, version FROM #{table} FINAL
        WHERE #{key} IN (#{tuples.join(', ')})
      SQL
    end.to_h do |row|
      [ [ row.fetch("user_id").to_i, row.fetch("id").to_i ], row.fetch("version").to_i ]
    end
    expected = rows.to_h do |row|
      [ [ row.fetch("user_id").to_i, row.fetch("id").to_i ], row.fetch("version").to_i ]
    end
    delivered = expected.all? { |key, version| visible.fetch(key, -1) >= version }
    raise "ClickHouse #{table} did not expose the delivered heartbeat versions" unless delivered
  end

  def verification_rows(table, records, columns:)
    records.each_slice(QUERY_BATCH_SIZE).flat_map do |batch|
      tuples = batch.map do |record|
        id = record_value(record, "id")
        user_id = record_value(record, "user_id")
        time = record_value(record, "time")
        second = time.to_f.floor
        bucket = five_minute_bucket(time)
        case table
        when "heartbeat_store"
          "(#{quote(user_id)}, #{quote(id)})"
        when "heartbeats"
          "(#{quote(user_id)}, #{bucket}, #{second}, #{quote(time)}, #{quote(id)})"
        when "heartbeats_by_time"
          "(#{bucket}, #{second}, #{quote(user_id)}, #{quote(time)}, #{quote(id)})"
        else
          raise ArgumentError, "Unknown heartbeat table: #{table}"
        end
      end
      key = case table
      when "heartbeat_store" then "(user_id, id)"
      when "heartbeats" then "(user_id, time_5m, time_second, time, id)"
      when "heartbeats_by_time" then "(time_5m, time_second, user_id, time, id)"
      end
      canonical = table == "heartbeat_store" ? "canonicalized = true AND duplicate_of IS NULL AND " : ""
      @client.select(<<~SQL.squish)
        SELECT #{columns.join(', ')} FROM #{table} FINAL
        WHERE #{canonical}#{key} IN (#{tuples.join(', ')})
        ORDER BY id
      SQL
    end
  end

  def activate_candidate(candidate, hashes: identity_hashes(candidate))
    hashes = (hashes + identity_hashes(candidate)).uniq
    aliases = alias_rows(candidate.fetch("user_id"), hashes)
    winner_ids = aliases.pluck("heartbeat_id").map(&:to_i).uniq
    winner_ids << candidate.fetch("duplicate_of").to_i if candidate["duplicate_of"]
    winner_ids.uniq!
    raise "Heartbeat aliases point to multiple identities" if winner_ids.many?

    if winner_ids.one? && winner_ids.sole != candidate.fetch("id").to_i
      unless candidate.fetch("canonicalized") && candidate.fetch("duplicate_of", nil).to_i == winner_ids.sole
        duplicate = replace_store_row(
          candidate,
          { "canonicalized" => true, "duplicate_of" => winner_ids.sole }
        )
        insert_store_rows([ duplicate ])
      end
      winner = current_store_row(candidate.fetch("user_id"), winner_ids.sole)
      write_aliases(winner, active: winner["deleted_at"].nil?, hashes:)
      return winner
    end

    active = candidate.fetch("canonicalized") ? candidate :
      replace_store_row(candidate, { "canonicalized" => true })
    insert_store_rows([ active ]) unless active.equal?(candidate)
    write_aliases(active, active: active["deleted_at"].nil?, hashes:)
    active
  end

  def write_aliases(row, active:, hashes: identity_hashes(row))
    user_id = row.fetch("user_id").to_i
    desired = hashes.to_h do |fields_hash|
      [ [ user_id, fields_hash ], {
        "user_id" => user_id,
        "heartbeat_id" => row.fetch("id").to_i,
        "active" => active
      } ]
    end
    write_alias_records(desired)
  end

  def write_aliases_for_rows(rows)
    desired = {}
    rows.each do |row|
      identity_hashes(row).each do |fields_hash|
        key = [ row.fetch("user_id").to_i, fields_hash ]
        existing = desired[key]
        record = {
          "user_id" => key.first,
          "fields_hash" => fields_hash,
          "heartbeat_id" => row.fetch("id").to_i,
          "active" => row["deleted_at"].nil?
        }
        if existing && existing.fetch("heartbeat_id") != record.fetch("heartbeat_id")
          if existing.fetch("active") && record.fetch("active")
            raise ActiveRecord::RecordNotUnique, "A heartbeat with this identity already exists"
          end
          record = existing if existing.fetch("active") ||
            (!record.fetch("active") && existing.fetch("heartbeat_id") > record.fetch("heartbeat_id"))
        end
        desired[key] = record
      end
    end
    write_alias_records(desired)
  end

  def write_alias_records(desired)
    return if desired.empty?

    current = desired.keys.each_slice(QUERY_BATCH_SIZE).flat_map do |keys|
      tuples = keys.map { |user_id, fields_hash| "(#{quote(user_id)}, #{quote(fields_hash)})" }.join(", ")
      @client.select(<<~SQL.squish)
        SELECT user_id, fields_hash, heartbeat_id, active, alias_version, updated_at
        FROM heartbeat_aliases FINAL
        WHERE (user_id, fields_hash) IN (#{tuples})
      SQL
    end.index_by { |row| [ row.fetch("user_id").to_i, row.fetch("fields_hash") ] }
    records = desired.filter_map do |key, record|
      record = record.merge("fields_hash" => key.last)
      alias_row = current[key]
      if alias_row && alias_row.fetch("heartbeat_id").to_i != record.fetch("heartbeat_id")
        if alias_row.fetch("active") && record.fetch("active")
          raise ActiveRecord::RecordNotUnique, "A heartbeat with this identity already exists"
        end
        next if alias_row.fetch("active") ||
          (!record.fetch("active") && alias_row.fetch("heartbeat_id").to_i > record.fetch("heartbeat_id"))
      end
      next if alias_row && alias_row.fetch("heartbeat_id").to_i == record.fetch("heartbeat_id") &&
        alias_row.fetch("active") == record.fetch("active")

      record
    end
    return if records.empty?

    version = next_version
    updated_at = serialized_time(Time.current)
    records.each { |record| record.merge!("alias_version" => version, "updated_at" => updated_at) }
    insert_rows("heartbeat_aliases", records)
  end

  def insert_store_rows(rows)
    insert_rows("heartbeat_store", rows.map { |row| row.stringify_keys.slice(*STORE_COLUMNS) })
  end

  def insert_rows(table, rows)
    return if rows.empty?

    rows.group_by { |row| insert_partition(table, row) }.each_value do |partition_rows|
      partition_rows.each_slice(INSERT_BATCH_SIZE) { |batch| insert_row_batch(table, batch) }
    end
  end

  def insert_row_batch(table, rows)
    token_payload = rows.map do |row|
      [ row["user_id"], row["id"] || row["heartbeat_id"], row["version"] || row["alias_version"], row["store_version"] ]
    end
    token = Digest::SHA256.hexdigest("#{table}:#{JSON.generate(token_payload)}")
    with_insert_retry do
      @client.insert_json_each_row(table, rows, settings: insert_settings(token))
    end
  end

  def insert_settings(token)
    {
      async_insert: 0,
      wait_for_async_insert: 1,
      insert_deduplication_token: token
    }
  end

  def with_insert_retry
    attempts = 0
    begin
      yield
    rescue ClickHouse::Client::Error, Timeout::Error, SocketError, IOError, EOFError,
      SystemCallError, OpenSSL::SSL::SSLError => error
      attempts += 1
      retryable = !error.is_a?(ClickHouse::Client::Error) || error.message.match?(RETRYABLE_INSERT_ERROR)
      retry_limit = Thread.current[@mutation_retry_key] || INSERT_RETRY_LIMIT
      raise unless retryable && attempts < retry_limit

      sleep(rand * 0.02 * (2**attempts))
      retry
    end
  end

  def insert_partition(table, row)
    case PARTITIONED_INSERTS[table]
    when "time"
      timestamp = row.fetch("time").to_f.floor
      timestamp.between?(0, 4_294_967_295) ? Time.at(timestamp).utc.strftime("%Y%m") : 0
    when "created_at"
      value = row.fetch("created_at")
      value.respond_to?(:strftime) ? value.utc.strftime("%Y%m") : value.to_s.first(7).delete("-")
    else
      0
    end
  end

  def current_store_row(user_id, heartbeat_id, required: true)
    row = store_rows("user_id = #{quote(user_id)} AND id = #{quote(heartbeat_id)}", limit: 1).first
    raise ActiveRecord::RecordNotFound, "Heartbeat #{heartbeat_id} was not found" if required && !row

    row
  end

  def store_rows_for_user(user_id, after_id: nil, limit: nil)
    predicates = [ "user_id = #{quote(user_id)}" ]
    predicates << "id > #{quote(after_id)}" if after_id
    store_rows(predicates.join(" AND "), order: "id", limit:)
  end

  def store_rows_for_user_ids(user_id, ids)
    ids.each_slice(QUERY_BATCH_SIZE).flat_map do |batch|
      store_rows(
        "user_id = #{quote(user_id)} AND id IN (#{batch.map { |id| quote(id) }.join(', ')})",
        order: "id"
      )
    end
  end

  def store_rows_by_keys(keys)
    return [] if keys.empty?

    keys.each_slice(QUERY_BATCH_SIZE).flat_map do |batch|
      tuples = batch.map { |user_id, id| "(#{quote(user_id)}, #{quote(id)})" }
      store_rows("(user_id, id) IN (#{tuples.join(', ')})", order: "id, user_id")
    end
  end

  def store_rows_for_aliases(user_id, hashes)
    hashes.uniq.each_slice(QUERY_BATCH_SIZE).flat_map do |batch|
      values = batch.map { |hash| quote(hash) }.join(", ")
      store_rows(<<~SQL.squish, order: "id")
        user_id = #{quote(user_id)} AND
        (fields_hash IN (#{values}) OR hasAny(alias_hashes, [#{values}]))
      SQL
    end.uniq { |row| [ row.fetch("user_id").to_i, row.fetch("id").to_i ] }
  end

  def stored_identities?(user_id, hashes)
    hashes.uniq.each_slice(QUERY_BATCH_SIZE).any? do |batch|
      values = batch.map { |hash| quote(hash) }.join(", ")
      @client.select(<<~SQL.squish).any?
        SELECT 1 AS present FROM (
          SELECT fields_hash FROM heartbeat_aliases FINAL
          WHERE user_id = #{quote(user_id)} AND fields_hash IN (#{values})
          UNION ALL
          SELECT fields_hash FROM heartbeat_store FINAL
          WHERE user_id = #{quote(user_id)} AND
            (fields_hash IN (#{values}) OR hasAny(alias_hashes, [#{values}]))
        ) LIMIT 1
      SQL
    end
  end

  def store_rows_for_ja4(ja4_id)
    store_rows("ja4_id = #{quote(ja4_id)} AND duplicate_of IS NULL", order: "user_id, id")
  end

  def store_rows(where, order: nil, limit: nil)
    sql = +"SELECT #{STORE_COLUMNS.join(', ')} FROM heartbeat_store FINAL WHERE #{where}"
    sql << " ORDER BY #{order}" if order
    sql << " LIMIT #{Integer(limit)}" if limit
    @client.select(sql)
  end

  def alias_rows(user_id, hashes)
    return [] if hashes.empty?

    hashes.each_slice(QUERY_BATCH_SIZE).flat_map do |batch|
      values = batch.map { |hash| quote(hash) }.join(", ")
      @client.select(<<~SQL.squish)
        SELECT user_id, fields_hash, heartbeat_id, active, alias_version, updated_at
        FROM heartbeat_aliases FINAL
        WHERE user_id = #{quote(user_id)} AND fields_hash IN (#{values})
      SQL
    end
  end

  def identity_hashes(row)
    [ row.fetch("fields_hash"), *Array(row["alias_hashes"]) ].compact.uniq.sort
  end

  def canonical_fields_hash(row)
    Heartbeat.generate_fields_hash(row.stringify_keys.except("user_id"))
  end

  def payload_hash(row)
    Digest::SHA256.hexdigest(JSON.generate(STORAGE_COLUMNS.to_h { |column| [ column, row[column] ] }))
  end

  def five_minute_bucket(value)
    second = value.to_f.floor
    (second / 300.0).truncate * 300
  end

  def record_value(record, column)
    record.respond_to?(:attributes) ? record.attributes.fetch(column) : record.fetch(column)
  end

  def with_mutation_timeouts(&block)
    with_clickhouse_timeouts(timeout: MUTATION_TIMEOUT, retry_limit: MUTATION_INSERT_RETRY_LIMIT, &block)
  end

  def with_clickhouse_timeouts(timeout:, retry_limit:, &block)
    return yield unless @client.respond_to?(:with_timeouts)

    previous_retry_limit = Thread.current[@mutation_retry_key]
    Thread.current[@mutation_retry_key] = retry_limit
    begin
      @client.with_timeouts(
        open_timeout: timeout,
        read_timeout: timeout,
        write_timeout: timeout,
        &block
      )
    ensure
      Thread.current[@mutation_retry_key] = previous_retry_limit
    end
  end

  def time_bucket(value) = "intDiv(toInt64(floor(#{quote(time_value(value))})), 300) * 300"

  def select_expression(value)
    string = value.respond_to?(:to_sql) ? value.to_sql : value.to_s
    return identifier(string) if STORAGE_COLUMNS.include?(string)

    string
      .gsub(/COUNT\(\*\) FILTER \(WHERE (.+)\)/i, 'countIf(\1)')
      .gsub(/COUNT\(\*\)/i, "count()")
      .gsub(/::integer/i, "")
  end

  def expression_alias(value)
    expression = select_expression(value)
    expression[/\s+AS\s+([a-zA-Z_][a-zA-Z0-9_]*)\z/i, 1] ||
      (STORAGE_COLUMNS.include?(value.to_s) ? value.to_s : expression)
  end

  def identifier(value)
    "`#{value.to_s.gsub('`', '``')}`"
  end

  def quote(value)
    case value
    when nil then "NULL"
    when true then "true"
    when false then "false"
    when Numeric
      raise ArgumentError, "non-finite number" unless value.finite?
      value.to_s
    when Time, DateTime then quote(value.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"))
    when Date then quote(value.iso8601)
    else "'#{value.to_s.gsub('\\') { '\\\\' }.gsub("'") { "\\'" }}'"
    end
  end

  def validate_column!(column)
    raise ArgumentError, "Unknown heartbeat column: #{column}" unless COLUMNS.include?(column)
  end

  def valid_timezone(timezone)
    TZInfo::Timezone.all_identifiers.include?(timezone) ? timezone : "UTC"
  end

  def epoch_datetime(expression, timezone)
    bounded = "least(greatest(toFloat64(#{expression}), 0.0), #{VALID_TIME_MAX}.0)"
    "fromUnixTimestamp64Micro(toInt64(round((#{bounded}) * 1000000)), #{quote(valid_timezone(timezone))})"
  end

  def serialized_time(value) = value.utc.strftime("%Y-%m-%d %H:%M:%S.%6N")

  def deserialize_dependencies!(attributes)
    dependencies_json = attributes.delete("dependencies_json")
    attributes["dependencies"] = JSON.parse(dependencies_json) if dependencies_json
    attributes["dependencies"] = nil if attributes.delete("dependencies_is_null")
  end

  def time_value(value)
    case value
    when Time, DateTime then value.to_f
    when Date then value.in_time_zone.to_f
    else value
    end
  end

  def user_lock_key(user_id) = "heartbeat-user:#{Integer(user_id)}"

  def pending_transfer?(user_id)
    HeartbeatTransfer.where.not(status: :completed)
      .where("from_user_id = :user_id OR to_user_id = :user_id", user_id:).exists?
  end

  def lock_user_ja4_changes(user_ids)
    return if user_ids.empty?

    store_ja4_ids_for_users(user_ids).sort.each { |ja4_id| lock_ja4_changes(ja4_id) }
  end

  def pending_nullification?(user_ids)
    return false if user_ids.empty?

    ja4_ids = store_ja4_ids_for_users(user_ids)
    HeartbeatJa4Nullification.where(ja4_id: ja4_ids, completed_at: nil).exists?
  end

  def reconcile_user_nullifications(user_ids, allow_transfer: false)
    return if user_ids.empty?

    HeartbeatJa4Nullification.where(ja4_id: store_ja4_ids_for_users(user_ids)).find_each do |nullification|
      nullify_ja4(
        nullification.ja4_id,
        version: nullification.clickhouse_version,
        allow_transfer:,
        user_ids:
      )
    end
  end

  def store_ja4_ids_for_users(user_ids)
    @client.select(<<~SQL.squish).pluck("ja4_id").compact.map(&:to_i)
      SELECT DISTINCT ja4_id FROM heartbeat_store FINAL
      WHERE user_id IN (#{user_ids.map { |user_id| quote(user_id) }.join(', ')})
        AND duplicate_of IS NULL AND ja4_id IS NOT NULL
    SQL
  end

  def latest_row_query?(scope, order:, limit:, offset:)
    limit == 1 && offset.nil? &&
      Array(order).first&.match?(/(?:`time`|\btime\b)\s+DESC/i) &&
      scope.conditions.any? { |condition| condition[:field] == :user_id } &&
      scope.conditions.none? { |condition| condition[:field] == :time }
  end

  def select_rows(scope, select:, order:, limit:, offset:)
    sql = scope.sql(select:, order:, limit:, offset:)
    return @client.select(sql) unless latest_row_query?(scope, order:, limit:, offset:)

    recent = scope.where(time: 25.hours.ago.to_f..)
    @client.select(recent.sql(select:, order:, limit:, offset:)).presence || @client.select(sql)
  end

  class Scope
    include Enumerable

    INVALID_VALUE = Object.new.freeze

    attr_reader :repository, :conditions, :group_values, :order_values, :limit_value, :offset_value,
      :select_values

    def initialize(repository, with_deleted: false, conditions: [], group_values: [], order_values: [],
                   limit_value: nil, offset_value: nil, select_values: [], distinct_value: false)
      @repository = repository
      @conditions = conditions
      @group_values = group_values
      @order_values = order_values
      @limit_value = limit_value
      @offset_value = offset_value
      @select_values = select_values
      @distinct_value = distinct_value
      @conditions += [ { sql: "deleted_at IS NULL", field: :deleted_at } ] unless with_deleted
    end

    def where(first = nil, *binds, **attributes)
      attributes = first if first.is_a?(Hash)
      additions = if attributes.any?
        attributes.map { |field, value| condition_for(field, value) }
      elsif first
        [ { sql: bind_sql(first.to_s, binds), field: inferred_field(first.to_s) } ]
      else
        []
      end
      new_scope(conditions: conditions + additions)
    end

    def not(first = nil, *binds, **attributes)
      attributes = first if first.is_a?(Hash)
      additions = if attributes.any?
        attributes.map { |field, value| condition_for(field, value, negate: true) }
      else
        [ { sql: "NOT (#{bind_sql(first.to_s, binds)})", field: inferred_field(first.to_s) } ]
      end
      new_scope(conditions: conditions + additions)
    end

    def or(other)
      left = conditions.map { |condition| condition.fetch(:sql) }.join(" AND ")
      right = other.conditions.map { |condition| condition.fetch(:sql) }.join(" AND ")
      left_user = conditions.find { |condition| condition[:field] == :user_id }
      right_user = other.conditions.find { |condition| condition[:field] == :user_id }
      metadata = if left_user && right_user
        { field: :user_id, multi_user: left_user[:multi_user] || right_user[:multi_user] }
      else
        { field: nil }
      end
      new_scope(conditions: [ { sql: "((#{left}) OR (#{right}))", **metadata } ])
    end

    def unscope(*values, where: nil)
      fields = Array(where).map(&:to_sym)
      replacement = fields.empty? ? conditions : conditions.reject { |condition| fields.include?(condition[:field]) }
      replacement = [] if values.include?(:where)
      new_scope(
        conditions: replacement,
        group_values: values.include?(:group) ? [] : group_values,
        order_values: values.include?(:order) ? [] : order_values,
        select_values: values.include?(:select) ? [] : select_values
      )
    end

    def with_deleted = unscope(where: :deleted_at)
    def only_deleted = with_deleted.where.not(deleted_at: nil)
    def with_valid_timestamps = where("time >= ? AND time <= ?", 0, VALID_TIME_MAX)
    def coding_only = where(category: "coding")
    def excluding_browser_time = where("editor IS NULL OR lower(editor) NOT IN (?)", BROWSER_EDITORS)
    def leaderboard_eligible = coding_only.excluding_browser_time.where("project IS DISTINCT FROM ?", "<<LAST_PROJECT>>").with_valid_timestamps
    def today = where(time: Time.current.beginning_of_day.to_i..Time.current.end_of_day.to_i)

    def recent
      cutoff = 24.hours.ago.to_i
      where(time: cutoff..).where("time > ?", cutoff)
    end

    def filter_by_time_range(interval, from = nil, to = nil)
      interval = interval&.to_sym
      return where(time: (from.present? ? Time.zone.parse(from).beginning_of_day.to_i : 0)..(to.present? ? Time.zone.parse(to).end_of_day.to_i : VALID_TIME_MAX)) if interval == :custom
      return public_send(interval) if TimeRangeFilterable::RANGES.key?(interval)

      self
    end

    TimeRangeFilterable::RANGES.each do |name, configuration|
      next if name == :today

      define_method(name) { where(time: configuration.fetch(:calculate).call) }
    end

    def group(*values) = new_scope(group_values: values.flatten.map(&:to_s))
    def order(*values, **mapping) = new_scope(order_values: order_values + order_sql(values, mapping))
    def reorder(*values, **mapping) = new_scope(order_values: order_sql(values, mapping))
    def limit(value) = new_scope(limit_value: value)
    def offset(value) = new_scope(offset_value: value)
    def select(*values) = new_scope(select_values: values.flatten)
    def distinct(value = true) = new_scope(distinct_value: value)
    def none = where("0")

    def each(&block)
      return enum_for(__method__) unless block

      repository.each_row(
        self,
        columns: select_values.presence || COLUMNS,
        order: order_values,
        limit: limit_value,
        offset: offset_value,
        &block
      )
    end
    def as_json(options = nil) = to_a.as_json(options)

    def to_a
      repository.rows(
        self,
        columns: select_values.presence || COLUMNS,
        order: order_values,
        limit: limit_value,
        offset: offset_value
      )
    end

    def first
      limit(1).to_a.first
    end

    def sole
      records = limit(2).to_a
      raise ActiveRecord::RecordNotFound if records.empty?
      raise ActiveRecord::SoleRecordExceeded if records.many?

      records.first
    end

    def exists? = !repository.aggregate(limit(1), "count()").to_i.zero?
    def empty? = !exists?
    def none? = !exists?
    def size = count
    def length = count

    def count(column = nil)
      return repository.grouped_count(self, group_values) if group_values.any?

      expression = if @distinct_value && column
        "uniqExact(#{repository.select_expression(column)})"
      elsif @distinct_value
        "uniqExact(tuple(#{STORAGE_COLUMNS.map { |name| repository.identifier(name) }.join(', ')}))"
      else
        "count()"
      end
      repository.aggregate(self, expression).to_i
    end

    def minimum(column) = numeric_aggregate("min", column)
    def maximum(column) = numeric_aggregate("max", column)

    def pluck(*columns)
      repository.pluck(
        self,
        columns,
        order: order_values,
        limit: limit_value,
        offset: offset_value
      )
    end

    def pick(*columns) = limit(1).pluck(*columns).first

    def duration_seconds = repository.duration_seconds(self)
    def duration_simple = Heartbeat.duration_simple(self)
    def duration_formatted = Heartbeat.duration_formatted(self)
    def to_span(timeout_duration: nil) = repository.spans(self, timeout: timeout_duration || Heartbeat.heartbeat_timeout_duration.to_i)

    def daily_durations(user_timezone:, start_date: 365.days.ago, end_date: Time.current)
      repository.daily_durations(self, timezone: user_timezone, start_time: start_date, end_time: end_date)
    end

    def sql(select: nil, group: nil, order: nil, limit: nil, offset: nil)
      selected = Array(select || select_values.presence || COLUMNS).map { |value| repository.select_expression(value) }
      selected = [ "DISTINCT #{selected.join(', ')}" ] if @distinct_value
      statement = +"SELECT #{selected.join(', ')} FROM #{physical_table} FINAL"
      prewhere, filtered = conditions.partition do |condition|
        condition[:field] == :user_agent && condition.fetch(:sql).match?(/\bILIKE\b/i)
      end
      statement << " PREWHERE #{prewhere.map { |condition| condition.fetch(:sql) }.join(' AND ')}" if prewhere.any?
      statement << " WHERE #{filtered.map { |condition| condition.fetch(:sql) }.join(' AND ')}" if filtered.any?
      grouped = Array(group || group_values)
      statement << " GROUP BY #{grouped.join(', ')}" if grouped.any?
      ordered = Array(order || order_values)
      statement << " ORDER BY #{ordered.join(', ')}" if ordered.any?
      statement << " LIMIT #{Integer(limit || limit_value)}" if limit || limit_value
      statement << " OFFSET #{Integer(offset || offset_value)}" if offset || offset_value
      statement
    end

    def to_sql = sql
    def model = Heartbeat
    def where_values_hash = {}
    def scope_for_create = {}
    def _exec_scope(*arguments, &block) = instance_exec(*arguments, &block)

    private

    def new_scope(**changes)
      self.class.new(
        repository,
        with_deleted: true,
        conditions: changes.fetch(:conditions, conditions),
        group_values: changes.fetch(:group_values, group_values),
        order_values: changes.fetch(:order_values, order_values),
        limit_value: changes.fetch(:limit_value, limit_value),
        offset_value: changes.fetch(:offset_value, offset_value),
        select_values: changes.fetch(:select_values, select_values),
        distinct_value: changes.fetch(:distinct_value, @distinct_value)
      )
    end

    def condition_for(field, value, negate: false)
      field = :user_id if field.to_sym == :user
      name = field.to_s
      repository.validate_column!(name)
      value = relation_values(value, field)
      value = normalize_value(value, field)
      expression = repository.identifier(name)
      sql = case value
      when INVALID_VALUE
        "0"
      when Range
        clauses = []
        clauses << "#{expression} >= #{repository.quote(time_value(value.begin, field))}" if value.begin
        if value.end
          operator = value.exclude_end? ? "<" : "<="
          clauses << "#{expression} #{operator} #{repository.quote(time_value(value.end, field))}"
        end
        clauses.join(" AND ")
      when Array
        values = value
        invalid_present = values.delete(INVALID_VALUE)
        if negate && invalid_present
          "0"
        else
          nil_present = values.include?(nil)
          values.delete(nil)
          clauses = []
          clauses << "#{expression} IS NULL" if nil_present
          clauses << "#{expression} IN (#{values.map { |item| repository.quote(item) }.join(', ')})" if values.any?
          clauses = [ "0" ] if clauses.empty?
          joined = clauses.join(" OR ")
          negate ? "NOT (#{joined})" : "(#{joined})"
        end
      when nil
        "#{expression} IS #{negate ? 'NOT ' : ''}NULL"
      else
        "#{expression} #{negate ? '!=' : '='} #{repository.quote(time_value(value, field))}"
      end
      if field.to_sym == :time && (bucket = time_bucket_condition(value, negate:))
        sql = "(#{bucket}) AND (#{sql})"
      end
      condition = { sql:, field: field.to_sym }
      condition[:multi_user] = value.many? if field.to_sym == :user_id && value.is_a?(Array)
      condition
    end

    def relation_values(value, field)
      return value unless value.is_a?(ActiveRecord::Relation)

      column = field.to_sym == :user_id ? :id : value.select_values.first || field
      value.pluck(column)
    end

    def normalize_value(value, field)
      return value.map { |item| normalize_value(item, field) } if value.is_a?(Array)
      if value.is_a?(Range)
        first = value.begin.nil? ? nil : normalize_value(value.begin, field)
        last = value.end.nil? ? nil : normalize_value(value.end, field)
        return INVALID_VALUE if first.equal?(INVALID_VALUE) || last.equal?(INVALID_VALUE)

        return Range.new(first, last, value.exclude_end?)
      end
      return value if value.nil?

      name = field.to_s
      if field.to_sym == :source_type
        return SOURCE_TYPES[value.to_s] if SOURCE_TYPES.key?(value.to_s)
        return Integer(value, exception: false) if value.to_s.match?(/\A\d+\z/)

        return INVALID_VALUE
      end
      return value unless HeartbeatRow::INTEGER_COLUMNS.include?(name)

      value.is_a?(Integer) ? value : Integer(value, exception: false) || INVALID_VALUE
    end

    def bind_sql(sql, binds)
      values = binds.dup
      field = inferred_field(sql)
      sql = sql.gsub(/\(\?\)/) do
        value = values.shift
        items = Array(value)
        "(#{items.map { |item| repository.quote(time_value(item, field)) }.join(', ')})"
      end
      sql.gsub("?") { repository.quote(time_value(values.shift, field)) }
        .gsub(/\bILIKE\b/i, "ILIKE")
    end

    def inferred_field(sql)
      COLUMNS.find { |column| sql.match?(/\b#{Regexp.escape(column)}\b/) }&.to_sym
    end

    def time_value(value, field)
      field&.to_sym == :time ? repository.time_value(value) : value
    end

    def time_bucket_condition(value, negate:)
      return if negate || value.nil?

      case value
      when Range
        clauses = []
        clauses << "time_5m >= #{repository.time_bucket(value.begin)}" if value.begin
        clauses << "time_5m <= #{repository.time_bucket(value.end)}" if value.end
        clauses.join(" AND ").presence
      when Numeric, Time, DateTime, Date
        "time_5m = #{repository.time_bucket(value)} AND time_second = toInt64(floor(#{repository.quote(repository.time_value(value))}))"
      end
    end

    def order_sql(values, mapping)
      entries = values.flatten.filter_map do |value|
        case value
        when Symbol then "#{repository.identifier(value)} ASC"
        when Hash then value.map { |field, direction| "#{repository.identifier(field)} #{direction.to_s.upcase}" }
        else value.respond_to?(:to_sql) ? value.to_sql : value.to_s
        end
      end.flatten
      entries + mapping.map { |field, direction| "#{repository.identifier(field)} #{direction.to_s.upcase}" }
    end

    def numeric_aggregate(function, column)
      value = repository.aggregate(self, "#{function}OrNull(#{repository.select_expression(column)})")
      value.nil? ? nil : value.to_f
    end

    def physical_table
      has_user_filter = conditions.any? { |condition| condition[:field] == :user_id }
      has_multi_user_filter = conditions.any? { |condition| condition[:field] == :user_id && condition[:multi_user] }
      has_time_filter = conditions.any? { |condition| condition[:field] == :time }
      ordered_by_time = order_values.first&.match?(/(?:`time`|\btime\b)\s+(?:ASC|DESC)/i)
      (has_time_filter || ordered_by_time) && (!has_user_filter || has_multi_user_filter) ? "heartbeats_by_time" : "heartbeats"
    end
  end
end
