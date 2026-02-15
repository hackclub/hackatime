module OauthAuthentication
  extend ActiveSupport::Concern

  class_methods do
    def hca_authorize_url(redirect_uri)
      params = {
        redirect_uri:,
        client_id: ENV["HCA_CLIENT_ID"],
        response_type: "code",
        scope: "email slack_id verification_status"
      }

      URI.parse("#{HCAService.host}/oauth/authorize?#{params.to_query}")
    end

    def slack_authorize_url(redirect_uri, close_window: false, continue_param: nil)
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

    def github_authorize_url(redirect_uri)
      params = {
        client_id: ENV["GITHUB_CLIENT_ID"],
        redirect_uri: redirect_uri,
        state: SecureRandom.hex(24),
        scope: "user:email"
      }

      URI.parse("https://github.com/login/oauth/authorize?#{params.to_query}")
    end

    def from_hca_token(code, redirect_uri)
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

      hca_data = ::HCAService.me(access_token)
      identity = hca_data["identity"]
      @user = User.find_by_hca_id(identity["id"]) unless identity["id"].blank?
      @user ||= User.find_by_slack_uid(identity["slack_id"]) unless identity["slack_id"].blank?
      @user ||= begin
                  EmailAddress.find_by(email: identity["primary_email"])&.user unless identity["primary_email"].blank?
                end

      @user.update(
        hca_scopes: hca_data["scopes"],
        hca_id: identity["id"],
        hca_access_token: access_token
      ) if !!@user

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

    def from_slack_token(code, redirect_uri)
      response = HTTP.post("https://slack.com/api/oauth.v2.access", form: {
        client_id: ENV["SLACK_CLIENT_ID"],
        client_secret: ENV["SLACK_CLIENT_SECRET"],
        code: code,
        redirect_uri: redirect_uri
      })

      data = JSON.parse(response.body.to_s)

      return nil unless data["ok"]

      user_response = HTTP.auth("Bearer #{data['authed_user']['access_token']}")
        .get("https://slack.com/api/users.info?user=#{data['authed_user']['id']}")

      user_data = JSON.parse(user_response.body.to_s)

      return nil unless user_data["ok"]

      slack_user = user_data["user"] || {}
      profile = slack_user["profile"] || {}

      email = profile["email"]&.downcase
      email_address = EmailAddress.find_or_initialize_by(email: email)
      user = email_address.user
      user ||= begin
        u = User.find_or_initialize_by(slack_uid: data.dig("authed_user", "id"))
        unless u.email_addresses.include?(email_address)
          u.email_addresses << email_address
        end
        u
      end

      user.email_addresses.source_slack.where.not(email: email).update_all(source: :signing_in)
      email_address.source = :slack
      email_address.save! if email_address.persisted?

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

    def from_github_token(code, redirect_uri, current_user)
      return nil unless current_user

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

      user_response = HTTP.auth("Bearer #{data['access_token']}")
        .get("https://api.github.com/user")

      user_data = JSON.parse(user_response.body.to_s)
      Rails.logger.info "GitHub user data: #{user_data.inspect}"
      Rails.logger.info "GitHub user ID type: #{user_data['id'].class}"

      github_uid = user_data["id"]
      other_users = User.where(github_uid: github_uid).where.not(id: current_user.id).where.not(github_access_token: nil)

      other_users.find_each do |user|
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
      Rails.logger.error "Error linking GitHub account: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      nil
    end
  end
end
