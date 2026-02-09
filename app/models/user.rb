class User < ApplicationRecord
  include TimezoneRegions
  include PublicActivity::Model
  include ::OauthAuthentication
  include ::SlackIntegration
  include ::GithubIntegration

  USERNAME_MAX_LENGTH = 21 # going over 21 overflows the navbar

  has_paper_trail

  after_create :create_signup_activity
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
  validate :username_must_be_visible

  attribute :allow_public_stats_lookup, :boolean, default: true
  attribute :default_timezone_leaderboard, :boolean, default: true

  def country_name
    ISO3166::Country.new(country_code).common_name
  end

  def country_subregion
    ISO3166::Country.new(country_code).subregion
  end

  enum :trust_level, {
    blue: 0,     # unscored
    red: 1,      # convicted
    green: 2,    # trusted
    yellow: 3    # suspected (invisible to user)
  }

  enum :admin_level, {
    default: 0,   # pleebs
    superadmin: 1,
    admin: 2,
    viewer: 3
  }, prefix: :admin_level

  def can_convict_users?
    admin_level_superadmin?
  end

  def set_admin_level(level)
    return false unless level.present? && self.class.admin_levels.key?(level)

    previous_level = admin_level

    if previous_level != level.to_s
      update!(admin_level: level.to_s)
    end

    true
  end

  def set_trust(level, changed_by_user: nil, reason: nil, notes: nil)
    return false unless level.present?

    previous_level = trust_level

    if changed_by_user.present? && level.to_s == "red" && !(changed_by_user.admin_level_superadmin?)
      return false
    end

    if previous_level != level.to_s
      if changed_by_user.present?
        trust_level_audit_logs.create!(
          changed_by: changed_by_user,
          previous_trust_level: previous_level,
          new_trust_level: level.to_s,
          reason: reason,
          notes: notes
        )
      end

      update!(trust_level: level)
    end

    true
  end
  # ex: .set_trust(:green) or set_trust(1) setting it to red

  has_many :heartbeats
  has_many :email_addresses, dependent: :destroy
  has_many :email_verification_requests, dependent: :destroy
  has_many :sign_in_tokens, dependent: :destroy
  has_many :project_repo_mappings


  has_many :hackatime_heartbeats,
    foreign_key: :user_id,
    primary_key: :slack_uid,
    class_name: "Hackatime::Heartbeat"

  has_many :project_labels,
    foreign_key: :user_id,
    primary_key: :slack_uid,
    class_name: "Hackatime::ProjectLabel"

  has_many :api_keys
  has_many :admin_api_keys, dependent: :destroy
  has_many :oauth_applications, as: :owner, dependent: :destroy

  has_one :sailors_log,
    foreign_key: :slack_uid,
    primary_key: :slack_uid,
    class_name: "SailorsLog"

  has_many :wakatime_mirrors, dependent: :destroy

  scope :search_identity, ->(term) {
    term = term.to_s.strip.downcase
    return none if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"

    left_joins(:email_addresses)
      .where(
        "LOWER(users.username) LIKE :p OR " \
        "LOWER(users.slack_username) LIKE :p OR " \
        "LOWER(users.github_username) LIKE :p OR " \
        "LOWER(email_addresses.email) LIKE :p OR " \
        "CAST(users.id AS TEXT) LIKE :p",
        p: pattern
      )
      .distinct
  }

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

  def streak_days
    @streak_days ||= heartbeats.daily_streaks_for_users([ id ]).values.first
  end

  def active_deletion_request
    deletion_requests.active.order(created_at: :desc).first
  end

  def pending_deletion?
    active_deletion_request.present?
  end

  def can_request_deletion?
    return false if pending_deletion?
    return true unless red?

    last_audit = trust_level_audit_logs.where(new_trust_level: :red).order(created_at: :desc).first
    return true unless last_audit

    last_audit.created_at <= 365.days.ago
  end

  def can_delete_emails?
    email_addresses.size > 1
  end

  def can_delete_email_address?(email)
    email.can_unlink? && can_delete_emails?
  end

  if Rails.env.development?
    def self.slow_find_by_email(email)
      EmailAddress.find_by(email: email)&.user
    end
  end

  def streak_days_formatted
    if streak_days > 30
      "30+"
    elsif streak_days < 1
      nil
    else
      streak_days.to_s
    end
  end

  enum :hackatime_extension_text_type, {
    simple_text: 0,
    clock_emoji: 1,
    compliment_text: 2
  }

  after_save :invalidate_activity_graph_cache, if: :saved_change_to_timezone?

  def data_migration_jobs
    GoodJob::Job.where(
      "serialized_params->>'arguments' = ?", [ id ].to_json
    ).where(
      "job_class = ?", "MigrateUserFromHackatimeJob"
    ).order(created_at: :desc).limit(10).all
  end

  def in_progress_migration_jobs?
    GoodJob::Job.where(job_class: "MigrateUserFromHackatimeJob")
                .where("serialized_params->>'arguments' = ?", [ id ].to_json)
                .where(finished_at: nil)
                .exists?
  end

  def format_extension_text(duration)
    case hackatime_extension_text_type
    when "simple_text"
      return "Start coding to track your time" if duration.zero?
      ::ApplicationController.helpers.short_time_simple(duration)
    when "clock_emoji"
      ::ApplicationController.helpers.time_in_emoji(duration)
    when "compliment_text"
      FlavorText.compliment.sample
    end
  end

  def parse_and_set_timezone(timezone)
    as_tz = ActiveSupport::TimeZone[timezone]

    unless as_tz
      begin
        tzinfo = TZInfo::Timezone.get(timezone)
        as_tz = ActiveSupport::TimeZone.all.find do |z|
          z.tzinfo.identifier == tzinfo.identifier
        end
      rescue TZInfo::InvalidTimezoneIdentifier
      end
    end

    if as_tz
      self.timezone = as_tz.name
    else
      Rails.logger.error "Invalid timezone #{timezone} for user #{id}"
    end
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

    base64_identicon = RubyIdenticon.create_base64(id.to_s)
    "data:image/png;base64,#{base64_identicon}"
  end

  def display_name
    name = slack_username || github_username || username
    return name if name.present?

    email = email_addresses&.first&.email
    return "error displaying name" unless email.present?

    email.split("@")&.first.truncate(10) + " (email sign-up)"
  end

  def most_recent_direct_entry_heartbeat
    heartbeats.where(source_type: :direct_entry).order(time: :desc).first
  end

  def create_email_signin_token(continue_param: nil)
    sign_in_tokens.create!(auth_type: :email, continue_param: continue_param)
  end

  def find_valid_token(token)
    sign_in_tokens.valid.find_by(token: token)
  end

  def self.not_convicted
    where.not(trust_level: User.trust_levels[:red])
  end

  def self.not_suspect
    where(trust_level: [ User.trust_levels[:blue], User.trust_levels[:green] ])
  end

  private

  def invalidate_activity_graph_cache
    Rails.cache.delete("user_#{id}_daily_durations")
  end

  def create_signup_activity
    create_activity :first_signup, owner: self
  end

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
    if instance_variable_defined?(:@username_cleared_for_invisible) && @username_cleared_for_invisible
      errors.add(:username, "must include visible characters")
    end
  end
end
