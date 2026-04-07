module GitlabIntegration
  extend ActiveSupport::Concern

  def raw_gitlab_user_info
    return nil unless gitlab_uid.present?
    return nil unless gitlab_access_token.present?

    @gitlab_user_info ||= HTTP.auth("Bearer #{gitlab_access_token}")
      .get("https://gitlab.com/api/v4/user")

    JSON.parse(@gitlab_user_info.body.to_s)
  end

  def gitlab_profile_url
    "https://gitlab.com/#{gitlab_username}" if gitlab_username.present?
  end
end
