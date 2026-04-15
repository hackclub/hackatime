class User < ApplicationRecord
  include TimezoneRegions
  include UserThemeConfiguration

  include ::Users::Identity
  include ::Users::AdminAndTrust
  include ::Users::Profile
  include ::Users::Authentication

  has_subscriptions

  USERNAME_MAX_LENGTH = 21 # going over 21 overflows the navbar

  has_paper_trail

  after_create :track_signup
  after_create :subscribe_to_default_lists
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

  has_many :heartbeats
  has_many :goals, dependent: :destroy
  has_many :email_addresses, dependent: :destroy
  has_many :email_verification_requests, dependent: :destroy
  has_many :sign_in_tokens, dependent: :destroy
  has_many :project_repo_mappings

  has_many :api_keys
  has_many :admin_api_keys, dependent: :destroy
  has_many :oauth_applications, as: :owner, dependent: :destroy

  has_one :sailors_log,
    foreign_key: :slack_uid,
    primary_key: :slack_uid,
    class_name: "SailorsLog"

  has_many :heartbeat_import_runs, dependent: :destroy

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

  def can_delete_emails?
    email_addresses.size > 1
  end

  def can_delete_email_address?(email)
    email.can_unlink? && can_delete_emails?
  end

  enum :hackatime_extension_text_type, {
    simple_text: 0,
    clock_emoji: 1,
    compliment_text: 2
  }

  after_save :invalidate_activity_graph_cache, if: :saved_change_to_timezone?

  def flipper_id
    "User;#{id}"
  end

  def github_profile_url
    "https://github.com/#{github_username}" if github_username.present?
  end

  def active_remote_heartbeat_import_run?
    heartbeat_import_runs.remote_imports.active_imports.exists?
  end

  def most_recent_direct_entry_heartbeat
    heartbeats.where(source_type: :direct_entry).order(time: :desc).first
  end

  private

  def invalidate_activity_graph_cache
    Rails.cache.delete("user_#{id}_daily_durations")
  end

  def track_signup
    PosthogService.identify(self)
    PosthogService.capture(self, "account_created", { source: "signup" })
  end

  def subscribe_to_default_lists
    subscribe("weekly_summary")
  end
end
