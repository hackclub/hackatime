# A rule that hides a user's heartbeats from every read without deleting them.
#
# A rule matches one user's heartbeats, optionally only one project, within an
# optional [starts_at, ends_at) range. Heartbeat's default scope hides rows that
# match any active rule; Heartbeat.with_excluded bypasses that. Revoking a rule
# restores its heartbeats and keeps the rule as history.
class HeartbeatExclusion < ApplicationRecord
  # Heartbeats live in ClickHouse and these rules live in Postgres, so the
  # active rules are compiled into a constant ClickHouse predicate. The rule set
  # is tiny (single digits) and is snapshotted once per request/job, so one
  # PG query per execution keeps every heartbeat read in that execution
  # consistent. Creating or revoking a rule resets the snapshot.

  # Every compiled visibility predicate contains this marker, so the test-suite
  # guard can tell filtered heartbeat SQL from unfiltered SQL.
  VISIBLE_MARKER = "heartbeats:visible".freeze

  # Marks SQL that intentionally reads hidden heartbeats. Heartbeat.with_excluded
  # adds it; raw SQL that must include hidden rows embeds INCLUDE_HIDDEN_COMMENT.
  INCLUDE_HIDDEN_TAG = "heartbeats:include_hidden"
  INCLUDE_HIDDEN_COMMENT = "/* #{INCLUDE_HIDDEN_TAG} */".freeze

  HEARTBEATS_TABLE_REFERENCE = /\b(?:FROM|JOIN|INTO|UPDATE)\s+(?:`?\w+`?\.)?`?heartbeats`?(?=[\s),;(]|\z)/i
  HEARTBEATS_READ_REFERENCE = /\b(?:FROM|JOIN)\s+(?:`?\w+`?\.)?`?heartbeats`?(?=[\s),;]|\z)/i
  STATEMENT_VERB = %r{\A\s*(?:/\*.*?\*/\s*)*(\w+)}m
  # Record#reload and find(id) bypass default scopes to fetch one known row.
  PRIMARY_KEY_LOOKUP = /\ASELECT (?:heartbeats\.\*|1 AS one) FROM heartbeats WHERE heartbeats\.id = \d+ LIMIT 1\z/

  # Per-execution snapshot of active rules: [[user_id, project, starts_epoch, ends_epoch], ...]
  class Snapshot < ActiveSupport::CurrentAttributes
    attribute :rules
  end

  def self.active_rules
    Snapshot.rules ||= active.pluck(:user_id, :project, :starts_at, :ends_at)
      .map { |user_id, project, starts_at, ends_at| [ user_id, project, starts_at&.to_r, ends_at&.to_r ] }
      .freeze
  end

  def self.reset_snapshot! = Snapshot.rules = nil

  # ClickHouse boolean expression that is true for heartbeats hidden by an
  # active rule. Each rule is coalesced to 0, so a NULL project can never make
  # the whole expression NULL. `table` qualifies columns for joins/self-joins.
  def self.matched_sql(table: nil)
    rules = active_rules
    return "0 /* #{VISIBLE_MARKER} */" if rules.empty?

    col = ->(name) { table ? "#{table}.#{name}" : name }
    conn = Heartbeat.connection
    clauses = rules.map do |user_id, project, starts_at, ends_at|
      parts = [ "#{col.(:user_id)} = #{Integer(user_id)}" ]
      parts << "#{col.(:project)} = #{conn.quote(project)}" unless project.nil?
      parts << "#{col.(:time)} >= #{starts_at.to_f}" unless starts_at.nil?
      parts << "#{col.(:time)} < #{ends_at.to_f}" unless ends_at.nil?
      "coalesce(#{parts.join(' AND ')}, 0)"
    end
    "(#{clauses.join(' OR ')} /* #{VISIBLE_MARKER} */)"
  end

  def self.visible_sql(table: nil) = "NOT #{matched_sql(table:)}"
  def self.hidden_sql(table: nil) = "toBool(#{matched_sql(table:)})"

  # True for SQL that reads heartbeats without the visibility predicate, or
  # writes through the filter and so skips hidden rows, unless it carries
  # INCLUDE_HIDDEN_TAG. The test suite raises on these.
  def self.unguarded_heartbeat_sql?(sql)
    return false if sql.include?(INCLUDE_HIDDEN_TAG) || sql.match?(PRIMARY_KEY_LOOKUP)

    filters = sql.scan(VISIBLE_MARKER).size
    case sql[STATEMENT_VERB, 1]&.upcase
    # Writes must reach hidden rows too, so they must not carry the filter.
    when "UPDATE", "DELETE", "ALTER" then filters.positive?
    # A plain INSERT ... VALUES reads nothing; INSERT ... SELECT reads like a SELECT.
    when "INSERT" then sql.scan(HEARTBEATS_READ_REFERENCE).size > filters
    else sql.scan(HEARTBEATS_READ_REFERENCE).size > filters
    end
  end

  # Per-user token that changes whenever one of the user's rules is created or
  # revoked. Per-user caches of heartbeat-derived data must include it in their keys.
  def self.cache_versions(user_ids)
    changed_at = where(user_id: user_ids).group(:user_id).maximum(:updated_at)
    Array(user_ids).index_with { |id| changed_at[id]&.utc&.strftime("x%s%6N") || "x0" }
  end

  # The where-clause node Heartbeat's default scope adds. It reports a pseudo
  # attribute so `unscope(where: :heartbeat_exclusions)` removes exactly this
  # predicate and keeps the rest of the relation.
  class VisibilityPredicate < Arel::Nodes::Grouping
    ATTRIBUTE = :heartbeat_exclusions

    def fetch_attribute = yield(Heartbeat.arel_table[ATTRIBUTE])
  end

  DATE_ONLY = /\A\d{4}-\d{2}-\d{2}\z/

  belongs_to :user
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :revoked_by, class_name: "User", optional: true

  enum :kind, { poison: 0, project_deletion: 1 }

  validates :ends_at, presence: true, if: :poison?
  validates :project, absence: true, if: :poison?
  validates :project, presence: true, if: :project_deletion?

  scope :active, -> { where(revoked_at: nil) }

  # Rule changes must be visible to the rest of this request/job immediately,
  # including later reads inside the same transaction, and a rolled-back
  # change must not linger in the snapshot.
  after_save :reset_snapshot
  after_commit :reset_snapshot
  after_rollback :reset_snapshot

  # Built lazily per query so the default scope always reflects the snapshot.
  def self.visibility_predicate = VisibilityPredicate.new(Arel.sql(visible_sql))

  # Resolves an admin-supplied poison cutoff to an instant.
  #
  # A bare date (YYYY-MM-DD or Date) covers that whole day in the user's time
  # zone, so the cutoff is the start of the next local day. Other strings are
  # parsed in the user's zone unless they carry an offset.
  def self.poison_cutoff(raw, timezone:)
    raise ArgumentError, "cutoff is required" if raw.blank?

    Time.use_zone(timezone.presence || "UTC") do
      if (date = date_only(raw))
        raise ArgumentError, "cutoff cannot be in the future" if date > Date.current
        date.in_time_zone.beginning_of_day + 1.day
      else
        instant = parse_instant(raw)
        raise ArgumentError, "cutoff is invalid" if instant.nil?
        raise ArgumentError, "cutoff cannot be in the future" if instant > Time.current
        instant
      end
    end
  end

  def self.date_only(raw)
    case raw
    when DateTime then nil
    when Date then raw
    when String then Date.iso8601(raw.strip) if raw.strip.match?(DATE_ONLY)
    end
  rescue Date::Error
    raise ArgumentError, "cutoff is invalid"
  end
  private_class_method :date_only

  def self.parse_instant(raw)
    case raw
    when Time, ActiveSupport::TimeWithZone, DateTime then raw
    when String then Time.zone.parse(raw.strip)
    end
  rescue ArgumentError
    nil
  end
  private_class_method :parse_instant

  def heartbeats
    scope = Heartbeat.with_excluded.where(user_id:)
    scope = scope.where(project:) if project
    scope = scope.where("time >= ?", starts_at.to_f) if starts_at
    scope = scope.where("time < ?", ends_at.to_f) if ends_at
    scope
  end

  def revoke!(by: nil) = update!(revoked_at: Time.current, revoked_by: by)

  private

  def reset_snapshot = self.class.reset_snapshot!
end
