require "cgi"
require "http"

module RepoHost
  class GitlabService < BaseService
    def fetch_repo_metadata
      return nil unless user.gitlab_access_token.present?

      repo_data = fetch_project_info
      return nil unless repo_data

      project_id = repo_data["id"]
      languages_data = fetch_languages(project_id)
      commits_data = fetch_recent_commits(project_id, repo_data["default_branch"])
      commit_count = fetch_commit_count(project_id, repo_data["default_branch"])

      {
        stars: repo_data["star_count"],
        description: repo_data["description"],
        language: repo_data["language"],
        languages: languages_data&.sort_by { |_, bytes| -bytes.to_f }&.map(&:first)&.join(", "),
        homepage: repo_data["homepage"].presence || repo_data["web_url"].presence,
        commit_count: commit_count,
        last_commit_at: commits_data&.first&.dig("created_at")&.then { |date| Time.parse(date) },
        last_synced_at: Time.current
      }
    end

    private

    def api_headers
      {
        "Authorization" => "Bearer #{user.gitlab_access_token}"
      }
    end

    def encoded_project_path
      CGI.escape("#{owner}/#{repo}")
    end

    def fetch_project_info
      make_api_request("https://gitlab.com/api/v4/projects/#{encoded_project_path}")
    end

    def fetch_languages(project_id)
      make_api_request("https://gitlab.com/api/v4/projects/#{project_id}/languages")
    end

    def fetch_recent_commits(project_id, default_branch = nil)
      ref_name = default_branch.present? ? "&ref_name=#{CGI.escape(default_branch)}" : ""
      make_api_request("https://gitlab.com/api/v4/projects/#{project_id}/repository/commits?per_page=5#{ref_name}")
    end

    def fetch_commit_count(project_id, default_branch = nil)
      ref_name = default_branch.present? ? "&ref_name=#{CGI.escape(default_branch)}" : ""
      response = HTTP.headers(api_headers)
                     .timeout(connect: 5, read: 10)
                     .get("https://gitlab.com/api/v4/projects/#{project_id}/repository/commits?per_page=1#{ref_name}")

      case response.status.code
      when 200
        response.headers["X-Total"]&.to_i || response.parse.size
      when 404
        Rails.logger.warn "[#{self.class.name}] Repository #{owner}/#{repo} not found for commit count"
        0
      else
        Rails.logger.warn "[#{self.class.name}] Failed to fetch commit count for #{owner}/#{repo}: #{response.status}"
        0
      end
    rescue => e
      report_error(e, message: "[#{self.class.name}] Error fetching commit count for #{owner}/#{repo}")
      0
    end
  end
end
