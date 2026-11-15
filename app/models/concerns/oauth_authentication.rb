module OauthAuthentication
  extend ActiveSupport::Concern
  include ErrorReporting

  # The identity's Slack ID or email is on an account linked to another HCA identity.
  class HCAIdentityConflictError < StandardError; end

  # Slack sign-in matched no account. Accounts are only created through HCA.
  class SlackAccountNotFoundError < StandardError; end

  # Attaches an HCA identity to this account. An identity that another account
  # holds moves here only when that account is unused, and the unused account
  # is then deleted. Raises HCAIdentityConflictError otherwise.
  def link_hca_identity!(access_token, hca_data, ip_address: nil)
    identity = hca_data["identity"]
    new_hca_id = identity["id"]
    slack_id = identity["slack_id"].presence
    attrs = { hca_scopes: hca_data["scopes"], hca_id: new_hca_id, hca_access_token: access_token }
    attrs[:country_code] = self.class.country_code_from_ip(ip_address) if country_code.blank?

    with_lock do
      # Another identity may have claimed this account since the caller looked it up.
      unless hca_id.nil? || hca_id == new_hca_id
        raise HCAIdentityConflictError, "HCA identity #{new_hca_id} matches User ##{id}, linked to another identity"
      end

      holder = self.class.lock.where.not(id:).find_by(hca_id: new_hca_id)
      if holder
        unless holder.unused?
          raise HCAIdentityConflictError, "HCA identity #{new_hca_id} belongs to User ##{holder.id}, which is in use"
        end

        # The emails follow the identity. Left behind, email and Slack sign-in
        # would keep finding the deleted account.
        holder.email_addresses.update_all(user_id: id)
        AnonymizeUserService.call(holder)
      end

      update!(attrs)
    end

    if slack_uid.blank? && slack_id
      begin
        update!(slack_uid: slack_id)
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
        raise if e.is_a?(ActiveRecord::RecordInvalid) && !e.record.errors.of_kind?(:slack_uid, :taken)

        reload
        report_message("HCA identity's Slack ID belongs to another account", level: :warn, extra: { user_id: id })
      end
    end
    SlackProfileSyncJob.perform_later(id) if slack_uid.present?
    self
  end

  # Nobody has tracked time, built on, been given privileges through or been
  # judged on this account, so nothing is lost when its identity moves to
  # another account.
  def unused?
    admin_level_default? &&
      blue? &&
      !Heartbeat.with_excluded.with_deleted.exists?(user_id: id) &&
      heartbeat_import_runs.none? &&
      oauth_applications.none?
  end

  class_methods do
    include ErrorReporting

    def hca_authorize_url(redirect_uri, state: nil, prompt: nil, login_hint: nil, scope: "email slack_id verification_status")
      URI.parse("#{HCAService.host}/oauth/authorize?#{{
        redirect_uri:,
        client_id: ENV["HCA_CLIENT_ID"],
        response_type: "code",
        scope:,
        state:,
        prompt:,
        login_hint:
      }.compact.to_query}")
    end

    def hca_id_from_token(code, redirect_uri)
      _access_token, hca_data = hca_identity_from_code(code, redirect_uri)
      hca_data&.dig("identity", "id")
    end

    # Exchanges an authorization code for the identity it belongs to. Returns
    # [access_token, me_response], or nil when the reply holds no identity.
    # Raises HTTP::Error when HCA is unreachable or answers with an error status.
    def hca_identity_from_code(code, redirect_uri)
      response = HTTP.use(:raise_error).post("#{HCAService.host}/oauth/token", form: {
        client_id: ENV["HCA_CLIENT_ID"], client_secret: ENV["HCA_CLIENT_SECRET"],
        redirect_uri:, code:, grant_type: "authorization_code"
      })
      token_data = JSON.parse(response.body.to_s)
      access_token = token_data["access_token"] if token_data.is_a?(Hash)
      return if access_token.blank?

      hca_data = HCAService.me(access_token)
      [ access_token, hca_data ] if hca_data.is_a?(Hash) && hca_data.dig("identity", "id").present?
    end

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

    def from_hca_token(code, redirect_uri, ip_address = nil)
      access_token, hca_data = hca_identity_from_code(code, redirect_uri)
      return nil if hca_data.nil?

      identity = hca_data["identity"]
      hca_id = identity["id"]
      slack_id = identity["slack_id"].presence
      email = identity["primary_email"].presence&.downcase

      user = find_by(hca_id:)
      if user.nil?
        # A Slack ID or email only identifies an account that no identity has claimed yet.
        owners = [
          (find_by(slack_uid: slack_id) if slack_id),
          (EmailAddress.find_by(email:)&.user if email)
        ].compact
        user = owners.find { |owner| owner.hca_id.nil? }
        if user.nil? && owners.any?
          raise HCAIdentityConflictError,
            "HCA identity #{hca_id} matches User ##{owners.map(&:id).uniq.join(', #')}, linked to another identity"
        end
      end

      if user
        user.link_hca_identity!(access_token, hca_data, ip_address:)
      else
        country_code = country_code_from_ip(ip_address)
        begin
          transaction do
            user = create!(
              hca_id:, slack_uid: slack_id, hca_scopes: hca_data["scopes"],
              hca_access_token: access_token, country_code:
            )
            EmailAddress.create!(email:, user:) if email
          end
        rescue ActiveRecord::RecordNotUnique
          # The same identity finished signing up in another request.
          user = find_by(hca_id:)
          raise if user.nil?
        end
        SlackProfileSyncJob.perform_later(user.id) if user.slack_uid.present?
      end
      user
    end

    def from_slack_token(code, redirect_uri, ip_address = nil)
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

      slack_user = user_data["user"] || {}
      email = (slack_user["profile"] || {})["email"]&.downcase
      slack_uid = data.dig("authed_user", "id")
      email_address = EmailAddress.find_or_initialize_by(email: email)
      if email_address.source_preserved_for_deletion?
        # An email kept from a deleted account does not reopen it. Only the
        # Slack ID identifies an account, and the email stays as it is.
        user = User.find_by(slack_uid:)
        raise SlackAccountNotFoundError if user.nil?
      else
        user = email_address.user || User.find_by(slack_uid:)&.tap do |u|
          u.email_addresses << email_address unless u.email_addresses.include?(email_address)
        end
        raise SlackAccountNotFoundError if user.nil?

        user.email_addresses.source_slack.where.not(email: email).update_all(source: :signing_in)
        email_address.source = :slack
        email_address.save! if email_address.persisted?
      end

      user.slack_uid = slack_uid
      user.apply_slack_profile_attributes(slack_user)
      user.parse_and_set_timezone(slack_user["tz"])
      user.slack_access_token = data["authed_user"]["access_token"]
      user.slack_scopes = data["authed_user"]["scope"]&.split(/,\s*/)
      user.country_code = country_code_from_ip(ip_address) if user.country_code.blank?
      user.save!
      user
    rescue SlackAccountNotFoundError
      raise
    rescue => e
      report_error(e, message: "Error creating user from Slack data: #{e.message}")
      nil
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

      user_data = JSON.parse(RepoHost::GithubService.get("https://api.github.com/user", token: data["access_token"]).body.to_s)
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
