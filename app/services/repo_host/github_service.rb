require "http"

module RepoHost
  class GithubService < BaseService
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
      {
        "Accept" => "application/vnd.github.v3+json",
        "Authorization" => "Bearer #{user.github_access_token}",
        "X-GitHub-Api-Version" => "2022-11-28"
      }
    end

    def fetch_repository_info
      url = "https://api.github.com/repos/#{owner}/#{repo}"
      make_api_request(url)
    end

    def fetch_languages
      url = "https://api.github.com/repos/#{owner}/#{repo}/languages"
      make_api_request(url)
    end

    def fetch_recent_commits
      # Get just the last few commits for metadata
      url = "https://api.github.com/repos/#{owner}/#{repo}/commits?per_page=5"
      make_api_request(url)
    end

    def fetch_commit_count(default_branch = nil)
      # GitHub API doesn't provide commit count directly, so we need to use a workaround
      # We'll get the commit count from the commits endpoint with minimal data
      branch_param = default_branch ? "&sha=#{default_branch}" : ""
      url = "https://api.github.com/repos/#{owner}/#{repo}/commits?per_page=1#{branch_param}"

      response = HTTP.headers(api_headers)
                     .timeout(connect: 5, read: 10)
                     .get(url)

      case response.status.code
      when 200
        # Extract commit count from Link header pagination
        link_header = response.headers["Link"]
        if link_header
          # Look for the "last" page number in the Link header
          # Format: <https://api.github.com/repos/owner/repo/commits?page=962&per_page=1>; rel="last"
          if match = link_header.match(/.*page=(\d+)[^>]*>;\s*rel="last"/)
            match[1].to_i
          else
            # If no "last" link, there's only one page of commits
            1
          end
        else
          # No Link header means there's only one page
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
      Rails.logger.error "[#{self.class.name}] Error fetching commit count for #{owner}/#{repo}: #{e.message}"
      0
    end
  end
end
