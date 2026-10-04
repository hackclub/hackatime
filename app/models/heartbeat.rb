class Heartbeat < ClickhouseRecord
  include Heartbeatable
  include TimeRangeFilterable

  time_range_filterable_field :time

  # Without this the adapter infers a composite key from ORDER BY (user_id, time, id).
  self.primary_key = "id"
  # This is to prevent Rails from trying to use STI even though we have a "type" column
  self.inheritance_column = nil

  # Ids continue Postgres's original heartbeats sequence, so they stay unique
  # across the migration and every API response keeps a stable integer id.
  ID_SEQUENCE = "heartbeats_id_seq".freeze

  # The adapter cannot parse the precision out of DateTime64(6, 'UTC'), so it
  # would silently drop microseconds on write. Declare it explicitly.
  %i[created_at updated_at deleted_at].each do |column|
    attribute column, ActiveRecord::ConnectionAdapters::Clickhouse::OID::DateTime.new(precision: 6)
  end

  # Default scope to exclude deleted records
  default_scope { where(deleted_at: nil) }
  default_scope { where(HeartbeatExclusion.visibility_predicate) }

  # Local midnight up to (not including) the next one, so the day's last second counts.
  scope :today, -> { where(time: Time.current.beginning_of_day.to_f...Time.current.tomorrow.beginning_of_day.to_f) }
  scope :recent, -> { where("time > ?", 24.hours.ago.to_i) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }
  scope :with_excluded, -> {
    unscope(where: HeartbeatExclusion::VisibilityPredicate::ATTRIBUTE).annotate(HeartbeatExclusion::INCLUDE_HIDDEN_TAG)
  }
  scope :with_hidden_flag, -> { select(arel_table[Arel.star], Arel.sql("#{HeartbeatExclusion.hidden_sql} AS hidden")) }

  enum :source_type, {
    direct_entry: 0,
    wakapi_import: 1,
    test_entry: 2
  }

  belongs_to :user
  belongs_to :ja4, optional: true

  validates :time, presence: true

  before_create :assign_id
  after_create :schedule_dashboard_rollup_refresh

  # Site-wide activity for the footer and homepage. Each scans every user's
  # recent heartbeats, so results are shared for a minute.
  SITE_ACTIVITY_CACHE_TTL = 1.minute

  def self.recent_count = recent_counts[:recent_count]
  def self.recent_imported_count = recent_counts[:recent_imported_count]

  def self.recent_counts
    Rails.cache.fetch("heartbeats/recent_counts", expires_in: SITE_ACTIVITY_CACHE_TTL) do
      direct = source_types.fetch("direct_entry")
      recent_count, recent_imported_count = recent.pluck(Arel.sql("count()"), Arel.sql("countIf(source_type != #{direct})")).first
      { recent_count:, recent_imported_count: }
    end
  end

  # Distinct coding users per hour over the last 24 hours, newest first.
  def self.active_users_by_hour
    Rails.cache.fetch("heartbeats/active_users_by_hour", expires_in: SITE_ACTIVITY_CACHE_TTL) do
      hours = coding_only.with_valid_timestamps
        .where("time > ?", 24.hours.ago.to_f).where("time < ?", Time.current.to_f)
        .group(Arel.sql("hour")).order(Arel.sql("hour DESC"))
        .pluck(Arel.sql("intDiv(toInt64(floor(time)), 3600) * 3600 AS hour"), Arel.sql("uniqExact(user_id)"))

      top = hours.map(&:last).max || 1
      hours.map { |hour, users| { hour: Time.at(hour), users:, height: (users.to_f / top * 100).round } }
    end
  end

  def self.minutes_logged_last_hour
    Rails.cache.fetch("heartbeats/minutes_logged_last_hour", expires_in: SITE_ACTIVITY_CACHE_TTL) do
      coding_only.with_valid_timestamps.where(time: 1.hour.ago.to_f..Time.current.to_f).duration_seconds / 60
    end
  end

  # A heartbeat's identity: two heartbeats are the same heartbeat (a client
  # resend) when all of these match. AI attributes only count when present.
  IDENTITY_ATTRIBUTES = %w[user_id branch category dependencies editor entity language machine operating_system project type user_agent line_additions line_deletions lineno lines cursorpos project_root_count time is_write].freeze
  AI_IDENTITY_ATTRIBUTES = %w[ai_model ai_session ai_subscription_plan ai_input_tokens ai_output_tokens ai_prompt_length ai_line_changes human_line_changes].freeze

  def self.identity_attributes(attributes)
    attributes = attributes.transform_keys(&:to_s)
    identity = attributes.slice(*IDENTITY_ATTRIBUTES)
    AI_IDENTITY_ATTRIBUTES.each { |name| identity[name] = attributes[name] unless attributes[name].nil? }
    identity
  end

  # Stable in-memory key for an identity, used to collapse repeats within one batch.
  def self.identity_key(attributes)
    identity = identity_attributes(attributes)
    identity["time"] = identity["time"].to_f unless identity["time"].nil?
    identity["user_id"] = identity["user_id"].to_i
    # Stored rows always read back an array; a missing list is the same heartbeat.
    identity["dependencies"] = Array(identity["dependencies"])
    identity.sort.to_json
  end

  INSERT_COLUMNS = %w[id user_id time project branch entity category editor language machine operating_system type user_agent ip_address dependencies dependencies_is_null lineno lines cursorpos line_additions line_deletions project_root_count is_write source_type ja4_id ai_model ai_session ai_subscription_plan ai_input_tokens ai_output_tokens ai_prompt_length ai_line_changes human_line_changes deleted_at created_at updated_at].freeze

  def self.row_for_insert(attributes)
    attrs = attributes.to_h.transform_keys(&:to_s)
    row = attrs.slice(*INSERT_COLUMNS)
    deps = attrs["dependencies"]
    row["dependencies"] = Array(deps).map(&:to_s)
    row["dependencies_is_null"] = deps.nil?
    source_type = attrs["source_type"]
    row["source_type"] = source_types.fetch(source_type.to_s, source_type).to_i unless source_type.nil?
    row["ip_address"] = attrs["ip_address"]&.to_s
    row.symbolize_keys
  end

  # Finds already-stored heartbeats with the same identity as any of the given
  # candidates, for one user. Hidden (excluded) heartbeats still own their
  # identity; soft-deleted ones do not. Returns { identity_key => Heartbeat }.
  #
  # One ClickHouse query: candidates narrow by (user_id, time) on the sort key,
  # then every identity attribute is compared exactly, with NULL equal to NULL.
  def self.existing_by_identity(user_id:, candidates:)
    return {} if candidates.empty?

    times = candidates.map { |attrs| (attrs[:time] || attrs["time"]).to_f }.uniq
    rows = unscoped.with_excluded
      .where(user_id:, deleted_at: nil, time: times)
      .order(:id)
      .to_a
    wanted = candidates.to_h { |attrs| [ identity_key(attrs.merge(user_id:)), true ] }
    rows.each_with_object({}) do |heartbeat, found|
      key = identity_key(heartbeat.attributes)
      found[key] ||= heartbeat if wanted.key?(key)
    end
  end

  # Reserves `count` ids from the Postgres sequence in one round trip.
  def self.allocate_ids(count)
    return [] if count <= 0

    ApplicationRecord.connection.select_values(
      ApplicationRecord.sanitize_sql([ "SELECT nextval(?) FROM generate_series(1, ?)", ID_SEQUENCE, count ])
    ).map(&:to_i)
  end

  # Inserts complete heartbeat rows. Rows without an id get one allocated.
  # Request-path writes use async inserts that wait for durability; pass
  # sync: true where the rows must be visible to the next query immediately and
  # identical blocks must never be dropped (tests, backfills).
  def self.insert_rows!(rows, sync: false)
    return [] if rows.empty?

    missing = rows.count { |row| row[:id].nil? && row["id"].nil? }
    ids = allocate_ids(missing).each
    rows = rows.map do |row|
      row = row.symbolize_keys
      row[:id] ||= ids.next
      row
    end
    settings = sync ? SYNC_INSERT_SETTINGS : INGEST_INSERT_SETTINGS
    with_clickhouse_settings(**settings) { insert_all!(rows) }
    rows
  end

  # Lightweight UPDATE: rewrites only deleted_at via a patch part, visible to
  # the next read. Never use update_all here; the adapter turns it into a heavy
  # ALTER TABLE mutation.
  # Only live rows are stamped, so a retry never moves an earlier deleted_at.
  def self.soft_delete_where!(user_id:, ids: nil, at: Time.current)
    set_deleted_at!(user_id:, ids:, value: at, only: "deleted_at IS NULL")
  end

  def self.restore_where!(user_id:, ids: nil)
    set_deleted_at!(user_id:, ids:, value: nil, only: "deleted_at IS NOT NULL")
  end

  def self.set_deleted_at!(user_id:, ids:, value:, only:)
    serialized = value && type_for_attribute(:deleted_at).serialize(value)
    conditions = [ "user_id = #{Integer(user_id)}", only ]
    conditions << "id IN (#{ids.map { |id| Integer(id) }.join(', ')})" if ids
    return if ids && ids.empty?

    # The adapter appends FORMAT ... to every statement unless the response
    # format is cleared; UPDATE does not accept a FORMAT clause.
    connection.with_response_format(nil) do
      connection.execute(<<~SQL.squish)
        /* #{HeartbeatExclusion::INCLUDE_HIDDEN_TAG} */
        UPDATE #{quoted_table_name} SET deleted_at = #{serialized.nil? ? 'NULL' : connection.quote(serialized)}
        WHERE #{conditions.join(' AND ')}
      SQL
    end
  end
  private_class_method :set_deleted_at!

  def soft_delete
    self.class.soft_delete_where!(user_id:, ids: [ id ])
    DashboardRollupRefreshJob.schedule_for(user_id)
  end

  def restore
    self.class.restore_where!(user_id:, ids: [ id ])
    DashboardRollupRefreshJob.schedule_for(user_id)
  end

  private

  def assign_id
    self.id ||= self.class.allocate_ids(1).first
    now = Time.current
    self.created_at ||= now
    self.updated_at ||= now
    self.dependencies ||= []
  end

  def schedule_dashboard_rollup_refresh = DashboardRollupRefreshJob.schedule_for(user_id)
end
