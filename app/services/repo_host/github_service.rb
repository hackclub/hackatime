require "http"

module RepoHost
  class GithubService < BaseService
    # Shared HTTP client for GitHub API. Used by services and jobs.
    def self.api_client(access_token)
      HTTP.headers(api_headers_for(access_token)).timeout(connect: 5, read: 10)
    end

    def self.api_headers_for(access_token)
      {
        "Accept" => "application/vnd.github.v3+json",
        "Authorization" => "Bearer #{access_token}",
        "X-GitHub-Api-Version" => "2022-11-28"
      }
    end

    def fetch_repo_metadata
      return nil unless user.github_access_token.present?

      # Fetch basic repository info
      repo_data = fetch_repository_info
      return nil unless repo_data

      # Fetch additional metadata
      languages_data = fetch_languages
      commits_data = fetch_recent_commits
      commit_count = fetch_commit_count(repo_data["default_branch"])

      {
        stars: repo_data["stargazers_count"],
        description: repo_data["description"],
        language: repo_data["language"],
        languages: languages_data&.keys&.join(", "),
        homepage: repo_data["homepage"].presence,
        commit_count: commit_count,
        last_commit_at: commits_data&.first&.dig("commit", "committer", "date")&.then { |date| Time.parse(date) },
        last_synced_at: Time.current
      }
    end

    private

    def api_headers
      self.class.api_headers_for(user.github_access_token)
    end

    def fetch_repository_info
      make_api_request("https://api.github.com/repos/#{owner}/#{repo}")
    end

    def fetch_languages
      make_api_request("https://api.github.com/repos/#{owner}/#{repo}/languages")
    end

    def fetch_recent_commits
      make_api_request("https://api.github.com/repos/#{owner}/#{repo}/commits?per_page=5")
    end

    def fetch_commit_count(default_branch = nil)
      # GitHub API doesn't provide commit count directly. Use Link header pagination on per_page=1.
      branch_param = default_branch ? "&sha=#{default_branch}" : ""
      url = "https://api.github.com/repos/#{owner}/#{repo}/commits?per_page=1#{branch_param}"
      response = self.class.api_client(user.github_access_token).get(url)

      case response.status.code
      when 200
        link_header = response.headers["Link"]
        if link_header && (match = link_header.match(/.*page=(\d+)[^>]*>;\s*rel="last"/))
          match[1].to_i
        else
          1
        end
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
