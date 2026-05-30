class User < ApplicationRecord
  has_one_attached :profile_og_image

  include UserThemeConfiguration
  include UserFuzzySearch
  include ::OauthAuthentication
  include ::SlackIntegration
  include ::GithubIntegration

  has_subscriptions

  USERNAME_MAX_LENGTH = 21 # going over 21 overflows the navbar

  has_paper_trail

  after_create :subscribe_to_default_lists
  after_create_commit :schedule_onboarding_check_in_email
  after_update_commit :clear_leaderboard_page_cache, if: :saved_change_to_leaderboard_shadowban_state?
  before_validation :normalize_username
  encrypts :slack_access_token, :github_access_token, :hca_access_token

  validates :slack_uid, uniqueness: true, allow_nil: true
  validates :github_uid, uniqueness: { conditions: -> { where.not(github_access_token: nil) } }, allow_nil: true
  validates :timezone, inclusion: { in: TZInfo::Timezone.all_identifiers }, allow_nil: false
  validates :country_code, inclusion: { in: ISO3166::Country.codes }, allow_nil: true
  validates :username,
    length: { maximum: USERNAME_MAX_LENGTH },
    format: { with: /\A[A-Za-z0-9_-]+\z/, message: "may only include letters, numbers, '-', and '_'" },
    uniqueness: { case_sensitive: false, message: "has already been taken" },
    allow_nil: true
  validates :leaderboard_shadowban_reason, presence: true, if: :leaderboard_shadowbanned?
  validate :username_must_be_visible

  attribute :allow_public_stats_lookup, :boolean, default: true
  attribute :default_timezone_leaderboard, :boolean, default: true
  attribute :show_goals_in_statusbar, :boolean, default: true

  def country_name = ISO3166::Country.new(country_code).common_name

  enum :trust_level, {
    blue: 0,     # unscored
    red: 1,      # convicted
    green: 2,    # trusted
    yellow: 3    # suspected (invisible to user)
  }

  def self.mask_trust_level(level)
    level.to_s == "yellow" ? "blue" : level.to_s
  end

  def public_trust_level = self.class.mask_trust_level(trust_level)

  enum :admin_level, {
    default: 0,   # pleebs
    superadmin: 1,
    admin: 2,
    viewer: 3,
    ultraadmin: 4
  }, prefix: :admin_level

  # Privilege ordering. The integer ordering on the enum is historical and does
  # NOT correspond to privilege; never compare admin_level numerically. Use this
  # rank table (or the helpers below) for any "outranks" check.
  ADMIN_LEVEL_RANK = {
    "default"    => 0,
    "viewer"     => 1, # read-only admin
    "admin"      => 2,
    "superadmin" => 3,
    "ultraadmin" => 4
  }.freeze

  enum :theme, {
    standard: 0,
    neon: 1,
    catppuccin_mocha: 2,
    catppuccin_iced_latte: 3,
    gruvbox_dark: 4,
    github_dark: 5,
    github_light: 6,
    nord: 7,
    rose: 8,
    rose_pine_dawn: 9,
    amoled: 10
  }

  # Look up a user by numeric ID, slack_uid, hca_id, or username
  def self.lookup_by_identifier(id)
    return nil if id.blank?

    numeric_id = id.to_i if id.match?(/^\d+$/)
    relation = where(slack_uid: id).or(where(hca_id: id)).or(where(username: id))
    relation = where(id: numeric_id).or(relation) if numeric_id

    candidates = relation.to_a
    lookup_order = [
      numeric_id && ->(u) { u.id == numeric_id },
      ->(u) { u.slack_uid == id },
      ->(u) { u.hca_id == id },
      ->(u) { u.username == id }
    ].compact
    lookup_order.each { |matcher| match = candidates.find(&matcher); return match if match }
    nil
  end

  def can_convict_users? = admin_level_superadmin? || admin_level_ultraadmin?
  def can_leaderboard_shadowban_users? = admin_level_superadmin? || admin_level_ultraadmin?
  def can_view_query_stats? = admin_level.in?(%w[viewer admin superadmin ultraadmin])
  def admin_level_rank = ADMIN_LEVEL_RANK[admin_level.to_s] || 0

  # True if `self` is allowed to set `target_user`'s admin_level to `new_level`.
  # Rules: only superadmin+ can change admin_level; no self-change; actor must
  # strictly outrank target's current level and be at/above the rank being
  # granted; granting `ultraadmin` requires `ultraadmin`.
  def can_change_admin_level_of?(target_user, new_level)
    return false unless ADMIN_LEVEL_RANK.key?(new_level.to_s)
    return false unless admin_level_superadmin? || admin_level_ultraadmin?
    return false unless can_act_on?(target_user)
    return false unless admin_level_rank >= (ADMIN_LEVEL_RANK[new_level.to_s] || 0)
    return false if new_level.to_s == "ultraadmin" && !admin_level_ultraadmin?

    true
  end

  # True if `self` is allowed to set `target_user`'s trust_level to `new_level`.
  # Rules: only admin+ can change trust; no self-change; actor must strictly
  # outrank target; setting `red` requires `can_convict_users?`.
  def can_change_trust_of?(target_user, new_level)
    return false unless self.class.trust_levels.key?(new_level.to_s)
    return false unless admin_level.in?(%w[admin superadmin ultraadmin])
    return false unless can_act_on?(target_user)
    return false if new_level.to_s == "red" && !can_convict_users?

    true
  end

  # Change a user's admin_level. Returns false on auth failure or invalid level.
  def set_admin_level(level, changed_by_user:) = change_level!(:admin_level, level, changed_by_user: changed_by_user)

  # Change a user's trust_level. Returns false on auth failure or invalid level.
  def set_trust(level, changed_by_user:, reason: nil, notes: nil)
    change_level!(:trust_level, level, changed_by_user: changed_by_user) do |previous_level, new_level|
      trust_level_audit_logs.create!(
        changed_by: changed_by_user,
        previous_trust_level: previous_level,
        new_trust_level: new_level,
        reason: reason,
        notes: notes
      )
    end
  end
  # ex: .set_trust(:green, changed_by_user: admin) or set_trust(:red, changed_by_user: admin)

  def set_leaderboard_shadowban(banned:, changed_by_user:, reason: nil)
    return false unless changed_by_user.is_a?(User)
    return false unless changed_by_user.can_leaderboard_shadowban_users?
    return false if changed_by_user == self
    return false unless changed_by_user.admin_level_rank > admin_level_rank

    update(
      leaderboard_shadowbanned: banned,
      leaderboard_shadowban_reason: banned ? reason.to_s.strip : nil,
      leaderboard_shadowbanned_by: banned ? changed_by_user : nil
    )
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error("set_leaderboard_shadowban failed for user #{id}: #{e.class}: #{e.message}")
    false
  end

  has_many :heartbeats
  has_many :goals, dependent: :destroy
  has_many :email_addresses, dependent: :destroy
  has_many :email_verification_requests, dependent: :destroy
  has_many :sign_in_tokens, dependent: :destroy
  has_many :project_repo_mappings

  has_many :api_keys
  has_many :admin_api_keys, dependent: :destroy
  has_many :oauth_applications, as: :owner, dependent: :destroy
  belongs_to :leaderboard_shadowbanned_by, class_name: "User", optional: true

  has_one :sailors_log,
    foreign_key: :slack_uid,
    primary_key: :slack_uid,
    class_name: "SailorsLog"

  has_many :heartbeat_import_runs, dependent: :destroy

  scope :search_identity, ->(term) {
    term = term.to_s.strip
    return none if term.blank?

    contains = "%#{sanitize_sql_like(term)}%"
    numeric_id = (term.match?(/\A\d+\z/) ? term.to_i : nil)

    parts = [
      "SELECT id FROM users WHERE slack_uid = :exact",
      "SELECT id FROM users WHERE username ILIKE :contains",
      "SELECT id FROM users WHERE slack_username ILIKE :contains",
      "SELECT id FROM users WHERE github_username ILIKE :contains",
      "SELECT user_id AS id FROM email_addresses WHERE email ILIKE :contains"
    ]
    parts << "SELECT id FROM users WHERE id = #{numeric_id}" if numeric_id

    candidates_sql = sanitize_sql_for_conditions([ parts.join(" UNION "), { exact: term, contains: contains } ])
    where("users.id IN (#{candidates_sql})")
  }

  def saved_change_to_leaderboard_shadowban_state?
    saved_change_to_leaderboard_shadowbanned? ||
      saved_change_to_leaderboard_shadowban_reason? ||
      saved_change_to_leaderboard_shadowbanned_by_id?
  end

  def clear_leaderboard_page_cache
    LeaderboardPageCache.clear!
  end

  has_many :trust_level_audit_logs, dependent: :destroy
  has_many :trust_level_changes_made, class_name: "TrustLevelAuditLog", foreign_key: "changed_by_id", dependent: :destroy
  has_many :deletion_requests, dependent: :restrict_with_error
  has_many :deletion_approvals, class_name: "DeletionRequest", foreign_key: "admin_approved_by_id"

  has_many :access_grants,
           class_name: "Doorkeeper::AccessGrant",
           foreign_key: :resource_owner_id,
           dependent: :delete_all

  has_many :access_tokens,
           class_name: "Doorkeeper::AccessToken",
           foreign_key: :resource_owner_id,
           dependent: :delete_all

  def streak_days = @streak_days ||= heartbeats.daily_streaks_for_users([ id ]).values.first
  def active_deletion_request = deletion_requests.active.order(created_at: :desc).first
  def pending_deletion? = active_deletion_request.present?

  def can_request_deletion?
    return false if pending_deletion?
    return true unless red?

    last_audit = trust_level_audit_logs.where(new_trust_level: :red).order(created_at: :desc).first
    return true unless last_audit

    last_audit.created_at <= 365.days.ago
  end

  def can_delete_emails? = email_addresses.size > 1
  def can_delete_email_address?(email) = email.can_unlink? && can_delete_emails?

  def streak_days_formatted
    streak_days > 30 ? "30+" : (streak_days < 1 ? nil : streak_days.to_s)
  end

  enum :hackatime_extension_text_type, {
    simple_text: 0,
    clock_emoji: 1,
    compliment_text: 2
  }

  after_update_commit :invalidate_activity_graph_cache, if: :saved_change_to_timezone?
  after_update_commit :schedule_dashboard_rollup_refresh, if: :saved_change_to_timezone?

  def flipper_id = "User;#{id}"
  def active_remote_heartbeat_import_run? = heartbeat_import_runs.remote_imports.active_imports.exists?
  def activity_graph_cache_key(timezone = self.timezone) = "user_#{id}_daily_durations_#{timezone}"

  def format_extension_text(duration)
    case hackatime_extension_text_type
    when "simple_text"
      return "Start coding to track your time" if duration.zero?
      ::ApplicationController.helpers.short_time_simple(duration)
    when "clock_emoji"
      ::ApplicationController.helpers.time_in_emoji(duration)
    when "compliment_text"
      compliments = FlavorText.compliment
      bucket = Time.now.to_i / (7 * 60)
      seed = Digest::MD5.hexdigest("#{id}-#{bucket}").to_i(16)
      compliments[Random.new(seed).rand(compliments.length)]
    end
  end

  def parse_and_set_timezone(timezone)
    as_tz = ActiveSupport::TimeZone[timezone]
    unless as_tz
      begin
        tzinfo = TZInfo::Timezone.get(timezone)
        as_tz = ActiveSupport::TimeZone.all.find { |z| z.tzinfo.identifier == tzinfo.identifier }
      rescue TZInfo::InvalidTimezoneIdentifier
      end
    end
    as_tz ? (self.timezone = as_tz.name) : report_message("Invalid timezone #{timezone} for user #{id}")
  end

  def avatar_url
    return self.slack_avatar_url if self.slack_avatar_url.present?
    return self.github_avatar_url if self.github_avatar_url.present?

    email = self.email_addresses&.first&.email
    if email.present?
      initials = email[0..1]&.upcase
      hashed_initials = Digest::SHA256.hexdigest(initials)[0..5]
      return "https://i2.wp.com/ui-avatars.com/api/#{initials}/48/#{hashed_initials}/fff?ssl=1"
    end
    "data:image/png;base64,#{RubyIdenticon.create_base64(id.to_s)}"
  end

  def display_name
    name = slack_username || github_username || username
    return name if name.present?
    email = email_addresses&.first&.email
    return "error displaying name" unless email.present?
    email.split("@")&.first.truncate(10) + " (email sign-up)"
  end

  def most_recent_direct_entry_heartbeat = heartbeats.where(source_type: :direct_entry).order(time: :desc).first

  def create_email_signin_token(continue_param: nil) = sign_in_tokens.create!(auth_type: :email, continue_param: continue_param)

  def rotate_api_keys!
    api_keys.transaction { api_keys.destroy_all; api_keys.create!(name: "Hackatime key") }
  end

  def rotate_single_api_key!(api_key)
    raise ActiveRecord::RecordNotFound unless api_key.user_id == id
    api_key.update!(token: SecureRandom.uuid_v4)
    api_key
  end

  def find_valid_token(token) = sign_in_tokens.valid.find_by(token: token)

  def self.not_convicted = where.not(trust_level: User.trust_levels[:red])
  def self.not_suspect = where(trust_level: [ User.trust_levels[:blue], User.trust_levels[:green] ])

  private

  # Shared precondition for can_change_admin_level_of? / can_change_trust_of?
  def can_act_on?(target_user)
    return false unless target_user.is_a?(User)
    return false if target_user == self

    admin_level_rank > (ADMIN_LEVEL_RANK[target_user.admin_level.to_s] || 0)
  end

  # Shared change body for set_admin_level / set_trust. Yields (previous, new)
  # when the value is actually changing, so callers can write audit logs.
  def change_level!(attr, level, changed_by_user:)
    return false unless changed_by_user.is_a?(User)
    levels_map = self.class.public_send(attr.to_s.pluralize)
    return false unless level.present? && levels_map.key?(level.to_s)

    auth_method = attr == :admin_level ? :can_change_admin_level_of? : :can_change_trust_of?
    return false unless changed_by_user.public_send(auth_method, self, level.to_s)

    previous_level = public_send(attr)
    if previous_level != level.to_s
      yield(previous_level, level.to_s) if block_given?
      update!(attr => level.to_s)
    end

    true
  end

  def invalidate_activity_graph_cache
    previous_timezone, current_timezone = previous_changes.fetch("timezone", [ nil, timezone ])

    [ previous_timezone, current_timezone ].compact.uniq.each do |cache_timezone|
      Rails.cache.delete(activity_graph_cache_key(cache_timezone))
    end
  end

  def schedule_dashboard_rollup_refresh = DashboardRollupRefreshJob.schedule_for(id, wait: 0.seconds)
  def subscribe_to_default_lists = subscribe("weekly_summary")
  def schedule_onboarding_check_in_email = OnboardingCheckInEmailJob.set(wait: 1.week).perform_later(id)

  def normalize_username
    original = username
    @username_cleared_for_invisible = false

    return if original.nil?

    cleaned = original.gsub(/\p{Cf}/, "")
    stripped = cleaned.strip

    if stripped.empty?
      self.username = nil
      @username_cleared_for_invisible = original.length.positive?
    else
      self.username = stripped
    end
  end

  def username_must_be_visible
    return unless instance_variable_defined?(:@username_cleared_for_invisible) && @username_cleared_for_invisible
    errors.add(:username, "must include visible characters")
  end
end
