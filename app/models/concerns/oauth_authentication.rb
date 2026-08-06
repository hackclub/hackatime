module OauthAuthentication
  extend ActiveSupport::Concern
  include ErrorReporting

  class HcaIdentityConflictError < StandardError
    attr_reader :hca_id, :reason, :email_user_id, :slack_user_id

    def initialize(hca_id:, reason:, email_user_id: nil, slack_user_id: nil)
      @hca_id = hca_id
      @reason = reason
      @email_user_id = email_user_id
      @slack_user_id = slack_user_id
      super(reason)
    end
  end

  class_methods do
    include ErrorReporting

    def slack_authorize_url(redirect_uri, state: nil, close_window: false, continue_param: nil)
      state ||= { token: SecureRandom.hex(24), close_window: close_window, continue: continue_param }.to_json
      URI.parse("https://slack.com/oauth/v2/authorize?#{{
        client_id: ENV["SLACK_CLIENT_ID"],
        redirect_uri: redirect_uri,
        state: state,
        user_scope: "users.profile:read,users.profile:write,users:read,users:read.email"
      }.to_query}")
    end

    def github_authorize_url(redirect_uri, state: nil)
      URI.parse("https://github.com/login/oauth/authorize?#{{
        client_id: ENV["GITHUB_CLIENT_ID"],
        redirect_uri: redirect_uri,
        state: state || SecureRandom.hex(24),
        scope: "user:email"
      }.to_query}")
    end

    def from_hca_identity(subject:, email:, slack_uid: nil, country_code: nil, retrying: false)
      email = email.to_s.strip.downcase
      slack_uid = slack_uid.presence
      return nil if subject.blank? || email.blank?

      user = transaction do
        subject_user = lock.find_by(hca_id: subject)
        if subject_user
          raise_hca_conflict!(subject:, reason: "anonymized", email_user: subject_user) unless subject_user.authentication_allowed?

          record_known_hca_conflict!(subject_user, subject:, email:, slack_uid:)
          sync_known_hca_user!(subject_user, email:, slack_uid:, country_code:)
          next subject_user
        end

        email_address = EmailAddress.lock.find_by("LOWER(email) = ?", email)
        email_user = email_address&.user
        slack_user = lock.find_by(slack_uid: slack_uid) if slack_uid

        if email_address&.source_preserved_for_deletion? || email_user&.anonymized? || slack_user&.anonymized?
          raise_hca_conflict!(subject:, reason: "anonymized", email_user:, slack_user:)
        end

        candidates = [ email_user, slack_user ].compact.uniq
        if candidates.many?
          raise_hca_conflict!(subject:, reason: "split_identity", email_user:, slack_user:)
        end

        candidate = candidates.first
        next nil unless candidate

        # Email and Slack lookups can reach the same legacy user through
        # different rows. Reload it under lock before deciding whether this
        # subject may claim it so concurrent HCA callbacks cannot overwrite
        # one another's subject.
        candidate.lock!

        reason =
          if !candidate.authentication_allowed?
            "anonymized"
          elsif candidate.hca_id.present?
            "subject_already_linked"
          elsif candidate.admin_level != "default"
            "elevated_account"
          elsif candidate.pending_deletion?
            "pending_deletion"
          elsif slack_uid && candidate.slack_uid.present? && candidate.slack_uid != slack_uid
            "slack_identity_mismatch"
          end
        raise_hca_conflict!(subject:, reason:, email_user:, slack_user:) if reason

        candidate.update!(
          hca_id: subject,
          slack_uid: candidate.slack_uid || slack_uid,
          country_code: candidate.country_code || country_code,
          hca_access_token: nil,
          hca_scopes: []
        )
        attach_hca_email!(candidate, email)
        candidate
      end

      SlackProfileSyncJob.perform_later(user.id) if user&.slack_uid.present?
      user
    rescue ActiveRecord::RecordNotUnique
      raise if retrying

      from_hca_identity(subject:, email:, slack_uid:, country_code:, retrying: true)
    end

    def create_from_hca_identity!(subject:, email:, slack_uid: nil, country_code: nil)
      existing_user = from_hca_identity(subject:, email:, slack_uid:, country_code:)
      return existing_user if existing_user

      user = transaction do
        created_user = create!(
          hca_id: subject,
          slack_uid: slack_uid.presence,
          country_code:,
          hca_access_token: nil,
          hca_scopes: []
        )
        created_user.email_addresses.create!(email:, source: :hca)
        created_user
      end
      SlackProfileSyncJob.perform_later(user.id) if user.slack_uid.present?
      user
    rescue ActiveRecord::RecordNotUnique
      from_hca_identity(subject:, email:, slack_uid:, country_code:) || raise
    end

    def sync_known_hca_user!(user, email:, slack_uid:, country_code:)
      claimed_slack_user = lock.find_by(slack_uid: slack_uid) if slack_uid
      attributes = {
        country_code: user.country_code || country_code,
        hca_access_token: nil,
        hca_scopes: []
      }
      attributes[:slack_uid] = slack_uid if user.slack_uid.blank? && claimed_slack_user.nil?
      user.update!(attributes)
      attach_hca_email!(user, email)
    end

    def attach_hca_email!(user, email)
      email_address = EmailAddress.find_by("LOWER(email) = ?", email)
      user.email_addresses.create!(email:, source: :hca) unless email_address
    end

    def record_known_hca_conflict!(user, subject:, email:, slack_uid:)
      email_user = EmailAddress.find_by("LOWER(email) = ?", email)&.user
      slack_user = find_by(slack_uid: slack_uid) if slack_uid
      return unless [ email_user, slack_user ].compact.any? { |claim_user| claim_user != user } || (slack_uid && user.slack_uid.present? && user.slack_uid != slack_uid)

      HCAIdentityConflict.record!(HcaIdentityConflictError.new(
        hca_id: subject,
        reason: "known_subject_claim_drift",
        email_user_id: email_user&.id,
        slack_user_id: slack_user&.id
      ))
    end

    def raise_hca_conflict!(subject:, reason:, email_user: nil, slack_user: nil)
      raise HcaIdentityConflictError.new(
        hca_id: subject,
        reason:,
        email_user_id: email_user&.id,
        slack_user_id: slack_user&.id
      )
    end

    def exchange_slack_code(code, redirect_uri)
      response = HTTP.post("https://slack.com/api/oauth.v2.access", form: {
        client_id: ENV["SLACK_CLIENT_ID"], client_secret: ENV["SLACK_CLIENT_SECRET"],
        code: code, redirect_uri: redirect_uri
      })
      data = JSON.parse(response.body.to_s)
      return nil unless data["ok"]

      user_response = HTTP.auth("Bearer #{data['authed_user']['access_token']}")
        .get("https://slack.com/api/users.info?user=#{data['authed_user']['id']}")
      user_data = JSON.parse(user_response.body.to_s)
      return nil unless user_data["ok"]

      {
        uid: data.dig("authed_user", "id"),
        access_token: data.dig("authed_user", "access_token"),
        scopes: data.dig("authed_user", "scope").to_s.split(/,\s*/),
        profile: user_data["user"] || {}
      }
    rescue JSON::ParserError, HTTP::Error => e
      report_error(e, message: "Slack OAuth exchange failed")
      nil
    end

    def connect_slack_identity!(user, identity)
      slack_uid = identity&.dig(:uid)
      return false unless user && slack_uid.present?

      user.with_lock do
        return false unless user.authentication_allowed?
        return false if user.pending_deletion?
        return false if user.slack_uid.present? && user.slack_uid != slack_uid
        return false if where(slack_uid:).where.not(id: user.id).exists?

        slack_user = identity[:profile]
        user.slack_uid ||= slack_uid
        user.apply_slack_profile_attributes(slack_user)
        user.parse_and_set_timezone(slack_user["tz"]) if slack_user["tz"].present?
        user.slack_access_token = identity[:access_token]
        user.slack_scopes = identity[:scopes]
        user.save!
        true
      end
    rescue ActiveRecord::RecordNotUnique
      user.reload
      false
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record == user && e.record.errors.of_kind?(:slack_uid, :taken)

      user.reload
      false
    end

    def country_code_from_ip(ip_address)
      Geocoder.search(ip_address).first&.country_code.presence&.upcase if ip_address.present?
    rescue => e
      report_error(e, message: "country geocode fail for signup IP")
      nil
    end

    def from_github_token(code, redirect_uri, current_user)
      return nil unless current_user

      response = HTTP.headers(accept: "application/json").post(
        "https://github.com/login/oauth/access_token",
        form: {
          client_id: ENV["GITHUB_CLIENT_ID"],
          client_secret: ENV["GITHUB_CLIENT_SECRET"],
          code: code,
          redirect_uri: redirect_uri
        }
      )
      data = JSON.parse(response.body.to_s)
      return nil unless data["access_token"]

      user_data = JSON.parse(HTTP.auth("Bearer #{data['access_token']}").get("https://api.github.com/user").body.to_s)
      github_uid = user_data["id"]

      User.where(github_uid: github_uid).where.not(id: current_user.id).where.not(github_access_token: nil).find_each do |user|
        Rails.logger.info "Clearing GitHub token for User ##{user.id} (GitHub UID: #{github_uid}) - linking to new account"
        user.update!(github_access_token: nil, github_uid: nil, github_username: nil)
      end

      current_user.github_uid = github_uid
      current_user.github_username = user_data["login"].presence || user_data["name"].presence
      current_user.github_avatar_url = user_data["avatar_url"]
      current_user.github_access_token = data["access_token"]
      current_user.save!

      ScanGithubReposJob.perform_later(current_user.id)
      current_user
    rescue => e
      report_error(e, message: "Error linking GitHub account: #{e.message}")
      nil
    end
  end
end
