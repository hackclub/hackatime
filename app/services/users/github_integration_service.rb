class Users::GithubIntegrationService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def raw_github_user_info
    return nil unless user.github_uid.present?
    return nil unless user.github_access_token.present?

    @github_user_info ||= HTTP.auth("Bearer #{user.github_access_token}")
      .get("https://api.github.com/user")

    JSON.parse(@github_user_info.body.to_s)
  end

  def github_profile_url
    "https://github.com/#{user.github_username}" if user.github_username.present?
  end
end
