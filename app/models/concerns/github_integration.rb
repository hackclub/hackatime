module GithubIntegration
  extend ActiveSupport::Concern

  def raw_github_user_info
    return nil unless github_uid.present?
    return nil unless github_access_token.present?

    @github_user_info ||= RepoHost::GithubService.get("https://api.github.com/user", token: github_access_token)

    JSON.parse(@github_user_info.body.to_s)
  end

  def github_profile_url
    "https://github.com/#{github_username}" if github_username.present?
  end
end
