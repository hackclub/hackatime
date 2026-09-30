# A rule that hides a user's heartbeats from every read without deleting them.
#
# A rule matches one user's heartbeats, optionally only one project, within an
# optional [starts_at, ends_at) range. Heartbeat's default scope hides rows that
# match any active rule; Heartbeat.with_excluded bypasses that. Revoking a rule
# restores its heartbeats and keeps the rule as history.
class HeartbeatExclusion < ApplicationRecord
  # Postgres predicate that is true when no active rule hides the heartbeat.
  # Raw SQL over the heartbeats table must include it to match model reads.
  VISIBLE_SQL = <<~SQL.squish.freeze
    NOT EXISTS (
      SELECT 1 FROM heartbeat_exclusions
      WHERE heartbeat_exclusions.user_id = heartbeats.user_id
        AND heartbeat_exclusions.revoked_at IS NULL
        AND (heartbeat_exclusions.project IS NULL OR heartbeat_exclusions.project = heartbeats.project)
        AND (heartbeat_exclusions.starts_at IS NULL OR heartbeats.time >= EXTRACT(EPOCH FROM heartbeat_exclusions.starts_at))
        AND (heartbeat_exclusions.ends_at IS NULL OR heartbeats.time < EXTRACT(EPOCH FROM heartbeat_exclusions.ends_at))
    )
  SQL

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

  # The heartbeats this rule matches, regardless of other rules.
  def heartbeats
    scope = Heartbeat.with_excluded.where(user_id:)
    scope = scope.where(project:) if project
    scope = scope.where("time >= ?", starts_at.to_f) if starts_at
    scope = scope.where("time < ?", ends_at.to_f) if ends_at
    scope
  end

  def revoke!(by: nil) = update!(revoked_at: Time.current, revoked_by: by)
end
