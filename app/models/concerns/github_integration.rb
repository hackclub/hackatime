module GithubIntegration
  extend ActiveSupport::Concern

  def github_profile_url
    "https://github.com/#{github_username}" if github_username.present?
  end
end
