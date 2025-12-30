class User < ApplicationRecord
  include TimezoneRegions
  include PublicActivity::Model

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
  has_one :mailing_address, dependent: :destroy
  has_many :physical_mails

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

  has_one :sailors_log,
    foreign_key: :slack_uid,
    primary_key: :slack_uid,
    class_name: "SailorsLog"

  has_many :wakatime_mirrors, dependent: :destroy

  has_many :trust_level_audit_logs, dependent: :destroy
  has_many :trust_level_changes_made, class_name: "TrustLevelAuditLog", foreign_key: "changed_by_id", dependent: :destroy
  has_many :deletion_requests, dependent: :destroy
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
    # don't let user delete emails if email count is <= 1
    email_addresses.size > 1
  end

  def can_delete_email_address?(email)
    email.can_unlink? && can_delete_emails?
  end

  if Rails.env.development?
    def self.slow_find_by_email(email)
      # This is an n+1 query, but provided for developer convenience
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

  def set_timezone_from_slack
    return unless slack_uid.present?

    user_response = HTTP.auth("Bearer #{slack_access_token}")
      .get("https://slack.com/api/users.info?user=#{slack_uid}")

    user_data = JSON.parse(user_response.body.to_s)

    return unless user_data["ok"]

    timezone_string = user_data.dig("user", "tz")

    return unless timezone_string.present?

    parse_and_set_timezone(timezone_string)
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


  def raw_github_user_info
    return nil unless github_uid.present?
    return nil unless github_access_token.present?

    @github_user_info ||= HTTP.auth("Bearer #{github_access_token}")
      .get("https://api.github.com/user")

    JSON.parse(@github_user_info.body.to_s)
  end

  def raw_slack_user_info
    return nil unless slack_uid.present?
    return nil unless slack_access_token.present?

    @slack_user_info ||= HTTP.auth("Bearer #{slack_access_token}")
      .get("https://slack.com/api/users.info?user=#{slack_uid}")

    JSON.parse(@slack_user_info.body.to_s).dig("user")
  end

  def update_from_slack
    user_data = raw_slack_user_info

    return unless user_data.present?

    profile = user_data["profile"] || {}

    self.slack_avatar_url = profile["image_192"] || profile["image_72"]

    self.slack_username = profile["display_name_normalized"].presence
    self.slack_username ||= profile["real_name_normalized"].presence
    self.slack_username ||= user_data["name"].presence
  end

  def update_slack_status
    return unless uses_slack_status?

    # check if the user already has a custom status set– if it doesn't look like
    # our format, don't clobber it

    current_status_response = HTTP.auth("Bearer #{slack_access_token}")
      .get("https://slack.com/api/users.profile.get")

    current_status = JSON.parse(current_status_response.body.to_s)

    custom_status_regex = /spent on \w+ today$/
    status_present = current_status.dig("profile", "status_text").present?
    status_custom = !current_status.dig("profile", "status_text")&.match?(custom_status_regex)

    return if status_present && status_custom

    current_project = heartbeats.order(time: :desc).first&.project
    current_project_duration = Time.use_zone(timezone) do
      heartbeats.where(project: current_project)
                .today
                .duration_seconds
    end
    current_project_duration_formatted = ApplicationController.helpers.short_time_simple(current_project_duration)

    # for 0 duration, don't set a status – this will let status expire when the user has not been cooking today
    return if current_project_duration.zero?

    status_emoji =
      case current_project_duration
      when 0...30.minutes
        %w[thinking cat-on-the-laptop loading-tumbleweed rac-yap]
      when 30.minutes...1.hour
        %w[working-parrot meow_code]
      when 1.hour...2.hours
        %w[working-parrot meow-code]
      when 2.hours...3.hours
        %w[working-parrot cat-typing bangbang]
      when 3.hours...5.hours
        %w[cat-typing meow-code laptop-fire bangbang]
      when 5.hours...8.hours
        %w[cat-typing laptop-fire hole-mantelpiece_clock keyboard-fire bangbang bangbang]
      when 8.hours...15.hours
        %w[laptop-fire bangbang bangbang rac_freaking rac_freaking hole-mantelpiece_clock]
      when 15.hours...20.hours
        %w[bangbang bangbang rac_freaking hole-mantelpiece_clock]
      else
        %w[areyousure time-to-stop]
      end.sample

    status_emoji = ":#{status_emoji}:"
    status_text = "#{current_project_duration_formatted} spent on #{current_project} today"

    # Update the user's status
    HTTP.auth("Bearer #{slack_access_token}")
      .post("https://slack.com/api/users.profile.set", form: {
        profile: {
          status_text:,
          status_emoji:,
          status_expiration: (Time.now + 10.minutes).to_i
        }
      })
  end

  def self.hca_authorize_url(redirect_uri)
    params = {
      redirect_uri:,
      client_id: ENV["HCA_CLIENT_ID"],
      response_type: "code",
      scope: "email slack_id verification_status"
    }

    URI.parse("#{HCAService.host}/oauth/authorize?#{params.to_query}")
  end

  def self.slack_authorize_url(redirect_uri, close_window: false, continue_param: nil)
    state = {
      token: SecureRandom.hex(24),
      close_window: close_window,
      continue: continue_param
    }.to_json

    params = {
      client_id: ENV["SLACK_CLIENT_ID"],
      redirect_uri: redirect_uri,
      state: state,
      user_scope: "users.profile:read,users.profile:write,users:read,users:read.email"
    }

    URI.parse("https://slack.com/oauth/v2/authorize?#{params.to_query}")
  end

  def self.github_authorize_url(redirect_uri)
    params = {
      client_id: ENV["GITHUB_CLIENT_ID"],
      redirect_uri: redirect_uri,
      state: SecureRandom.hex(24),
      scope: "user:email"
    }

    URI.parse("https://github.com/login/oauth/authorize?#{params.to_query}")
  end

  def self.from_hca_token(code, redirect_uri)
    # Exchange code for token
    response = HTTP.post("#{HCAService.host}/oauth/token", form: {
      client_id: ENV["HCA_CLIENT_ID"],
      client_secret: ENV["HCA_CLIENT_SECRET"],
      redirect_uri: redirect_uri,
      code: code,
      grant_type: "authorization_code"
    })

    data = JSON.parse(response.body.to_s)

    access_token = data["access_token"]
    return nil if access_token.nil?

    # get user info
    hca_data = ::HCAService.me(access_token)
    identity = hca_data["identity"]
    # find by HCA ID
    @user = User.find_by_hca_id(identity["id"]) unless identity["id"].blank?
    # find by slack_id
    @user ||= User.find_by_slack_uid(identity["slack_id"]) unless identity["slack_id"].blank?
    # find by email
    @user ||= begin
                EmailAddress.find_by(email: identity["primary_email"])&.user unless identity["primary_email"].blank?
              end

    # update scopes etc if user exists
    @user.update(
      hca_scopes: hca_data["scopes"],
      hca_id: identity["id"],
      hca_access_token: access_token
    ) if !!@user

    # if no user, create one
    @user ||= begin
                u = User.create!(
                  hca_id: identity["id"],
                  slack_uid: identity["slack_id"],
                  hca_scopes: hca_data["scopes"],
                  hca_access_token: access_token,
                )
                EmailAddress.create!(email: identity["primary_email"], user: u) unless identity["primary_email"].blank?
                u
              end
  end

  def self.from_slack_token(code, redirect_uri)
    # Exchange code for token
    response = HTTP.post("https://slack.com/api/oauth.v2.access", form: {
      client_id: ENV["SLACK_CLIENT_ID"],
      client_secret: ENV["SLACK_CLIENT_SECRET"],
      code: code,
      redirect_uri: redirect_uri
    })

    data = JSON.parse(response.body.to_s)

    return nil unless data["ok"]

    # Get user info
    user_response = HTTP.auth("Bearer #{data['authed_user']['access_token']}")
      .get("https://slack.com/api/users.info?user=#{data['authed_user']['id']}")

    user_data = JSON.parse(user_response.body.to_s)

    return nil unless user_data["ok"]

    slack_user = user_data["user"] || {}
    profile = slack_user["profile"] || {}

    email = profile["email"]&.downcase
    email_address = EmailAddress.find_or_initialize_by(email: email)
    email_address.source ||= :slack
    user = email_address.user
    user ||= begin
      u = User.find_or_initialize_by(slack_uid: data.dig("authed_user", "id"))
      unless u.email_addresses.include?(email_address)
        u.email_addresses << email_address
      end
      u
    end

    user.slack_uid = data.dig("authed_user", "id")
    user.slack_username = profile["display_name_normalized"].presence
    user.slack_username ||= profile["real_name_normalized"].presence
    user.slack_username ||= slack_user["name"].presence
    user.slack_avatar_url = profile["image_192"] || profile["image_72"]

    user.parse_and_set_timezone(slack_user["tz"])

    user.slack_access_token = data["authed_user"]["access_token"]
    user.slack_scopes = data["authed_user"]["scope"]&.split(/,\s*/)

    user.save!
    user
  rescue => e
    Rails.logger.error "Error creating user from Slack data: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  def self.from_github_token(code, redirect_uri, current_user)
    return nil unless current_user

    # Exchange code for token
    response = HTTP.headers(accept: "application/json")
      .post("https://github.com/login/oauth/access_token", form: {
        client_id: ENV["GITHUB_CLIENT_ID"],
        client_secret: ENV["GITHUB_CLIENT_SECRET"],
        code: code,
        redirect_uri: redirect_uri
      })

    data = JSON.parse(response.body.to_s)
    Rails.logger.info "GitHub OAuth response: #{data.inspect}"
    return nil unless data["access_token"]

    # Get user info
    user_response = HTTP.auth("Bearer #{data['access_token']}")
      .get("https://api.github.com/user")

    user_data = JSON.parse(user_response.body.to_s)
    Rails.logger.info "GitHub user data: #{user_data.inspect}"
    Rails.logger.info "GitHub user ID type: #{user_data['id'].class}"

    # Clear GitHub access tokens from any other users with this GitHub UID
    github_uid = user_data["id"]
    other_users = User.where(github_uid: github_uid).where.not(id: current_user.id).where.not(github_access_token: nil)

    other_users.find_each do |user|
      Rails.logger.info "Clearing GitHub token for User ##{user.id} (GitHub UID: #{github_uid}) - linking to new account"
      user.update!(github_access_token: nil, github_uid: nil, github_username: nil)
    end

    # Update GitHub-specific fields
    current_user.github_uid = github_uid
    current_user.github_username = user_data["login"].presence || user_data["name"].presence
    current_user.github_avatar_url = user_data["avatar_url"]
    current_user.github_access_token = data["access_token"]

    # Save the user
    current_user.save!

    ScanGithubReposJob.perform_later(current_user.id)

    current_user
  rescue => e
    Rails.logger.error "Error linking GitHub account: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
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
    name = slack_username || github_username
    return name if name.present?

    # "zach@hackclub.com" -> "zach (email sign-up)"
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

  # New method for GitHub profile URL
  def github_profile_url
    "https://github.com/#{github_username}" if github_username.present?
  end

  # Returns users that are not convicted (red)
  # For public APIs - includes blue, green, and yellow (suspected) users
  def self.not_convicted
    where.not(trust_level: User.trust_levels[:red])
  end

  # Returns only unscored (blue) and trusted (green) users
  # Excludes suspected (yellow) and convicted (red) users
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
