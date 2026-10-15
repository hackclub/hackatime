# A rule that hides a user's heartbeats from every read without deleting them.
#
# A rule matches one user's heartbeats, optionally only one project, within an
# optional [starts_at, ends_at) range. Heartbeat's default scope hides rows that
# match any active rule; Heartbeat.with_excluded bypasses that. Revoking a rule
# restores its heartbeats and keeps the rule as history.
class HeartbeatExclusion < ApplicationRecord
  # Raw SQL over the heartbeats table must filter on VISIBLE_SQL to match model reads.
  MATCHED_SQL = <<~SQL.squish.freeze
    EXISTS (
      SELECT 1 FROM heartbeat_exclusions
      WHERE heartbeat_exclusions.user_id = heartbeats.user_id
        AND heartbeat_exclusions.revoked_at IS NULL
        AND (heartbeat_exclusions.project IS NULL OR heartbeat_exclusions.project = heartbeats.project)
        AND (heartbeat_exclusions.starts_at IS NULL OR heartbeats.time >= EXTRACT(EPOCH FROM heartbeat_exclusions.starts_at))
        AND (heartbeat_exclusions.ends_at IS NULL OR heartbeats.time < EXTRACT(EPOCH FROM heartbeat_exclusions.ends_at))
    )
  SQL
  VISIBLE_SQL = "NOT #{MATCHED_SQL}".freeze
  # Select-list form of MATCHED_SQL. The IN check is a hashed lookup, so the
  # correlated EXISTS only runs for heartbeats of users with an active rule.
  HIDDEN_SQL = <<~SQL.squish.freeze
    (heartbeats.user_id IN (SELECT user_id FROM heartbeat_exclusions WHERE revoked_at IS NULL) AND #{MATCHED_SQL})
  SQL

  # Marks SQL that intentionally reads hidden heartbeats. Heartbeat.with_excluded
  # adds it; raw SQL that must include hidden rows embeds INCLUDE_HIDDEN_COMMENT.
  INCLUDE_HIDDEN_TAG = "heartbeats:include_hidden"
  INCLUDE_HIDDEN_COMMENT = "/* #{INCLUDE_HIDDEN_TAG} */".freeze

  HEARTBEATS_TABLE_REFERENCE = /\b(?:FROM|JOIN)\s+"?heartbeats"?(?=[\s),;]|\z)/i
  STATEMENT_VERB = %r{\A\s*(?:/\*.*?\*/\s*)*(\w+)}m
  # Record#reload and find(id) bypass default scopes to fetch one known row.
  PRIMARY_KEY_LOOKUP = /\ASELECT [^;]* FROM "heartbeats" WHERE "heartbeats"\."id" = \$1 LIMIT \$2\z/

  # True for SQL that reads heartbeats without filtering every reference with
  # VISIBLE_SQL, or writes through the filter and so skips hidden rows, unless
  # it carries INCLUDE_HIDDEN_TAG. The test suite raises on these.
  def self.unguarded_heartbeat_sql?(sql)
    return false if sql.include?(INCLUDE_HIDDEN_TAG) || sql.match?(PRIMARY_KEY_LOOKUP)

    filters = sql.scan(VISIBLE_SQL).size
    case sql[STATEMENT_VERB, 1]&.upcase
    when "UPDATE", "DELETE" then filters.positive?
    when "INSERT" then false
    else sql.scan(HEARTBEATS_TABLE_REFERENCE).size > filters
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

  def self.visibility_predicate = VisibilityPredicate.new(Arel.sql(VISIBLE_SQL))

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
end
