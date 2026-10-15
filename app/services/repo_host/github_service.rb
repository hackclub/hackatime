require "http"

module RepoHost
  class GithubService < BaseService
    extend ErrorReporting

    MAX_REDIRECTS = 3
    SECONDARY_LIMIT_FALLBACK = 60.seconds

    # Every GitHub REST call goes through here. It logs the outcome and the
    # remaining allowance, and stops using a token once GitHub has rate limited
    # it, because continuing to send requests while limited can get the
    # integration banned.
    def self.get(url, token:)
      cache_key = rate_limit_cache_key(token)
      if (retry_at = Rails.cache.read(cache_key)) && retry_at.future?
        raise RateLimitError.new("GitHub token is rate limited until #{retry_at.iso8601}", retry_at:)
      end

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = api_client(token).follow(max_hops: MAX_REDIRECTS).get(url)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      record_response(response, url, token, duration_ms)
      response
    end

    def self.api_client(access_token)
      HTTP.headers(
        "Accept" => "application/vnd.github+json",
        "Authorization" => "Bearer #{access_token}",
        "X-GitHub-Api-Version" => "2022-11-28"
      ).timeout(connect: 5, read: 10)
    end

    def self.rate_limit_cache_key(token)
      "github_api_rate_limited:#{token_fingerprint(token)}"
    end

    def self.token_fingerprint(token)
      Digest::SHA256.hexdigest(token.to_s)[0, 16]
    end

    def self.record_response(response, url, token, duration_ms)
      headers = response.headers
      payload = {
        endpoint: endpoint_template(url),
        status: response.status.code,
        duration_ms:,
        token: token_fingerprint(token),
        rate_limit_resource: headers["X-RateLimit-Resource"],
        rate_limit_limit: headers["X-RateLimit-Limit"]&.to_i,
        rate_limit_remaining: headers["X-RateLimit-Remaining"]&.to_i,
        rate_limit_reset: headers["X-RateLimit-Reset"]&.to_i
      }
      limit = rate_limit_from(response)
      payload[:rate_limit] = limit&.fetch(:kind)

      Rails.logger.info("[GitHubAPI] #{payload.compact.map { |key, value| "#{key}=#{value}" }.join(' ')}")
      return unless limit

      Rails.cache.write(rate_limit_cache_key(token), limit[:retry_at], expires_at: limit[:retry_at])
      message = "GitHub #{limit[:kind]} rate limit hit on #{payload[:endpoint]}; pausing token #{payload[:token]} until #{limit[:retry_at].iso8601}"
      if limit[:kind] == :secondary
        report_message(message, level: :warn, extra: payload)
      else
        Rails.logger.warn(message)
      end
      raise RateLimitError.new(message, retry_at: limit[:retry_at])
    end

    def self.rate_limit_from(response)
      return unless [ 403, 429 ].include?(response.status.code)

      headers = response.headers
      if headers["Retry-After"].present?
        { kind: :secondary, retry_at: Time.current + headers["Retry-After"].to_i.seconds }
      elsif headers["X-RateLimit-Remaining"] == "0"
        { kind: :primary, retry_at: Time.zone.at(headers["X-RateLimit-Reset"].to_i) }
      elsif response.status.code == 429 || response.body.to_s.match?(/secondary rate limit/i)
        { kind: :secondary, retry_at: Time.current + SECONDARY_LIMIT_FALLBACK }
      end
    end

    def self.endpoint_template(url)
      URI.parse(url).path
        .sub(%r{\A/repos/[^/]+/[^/]+}, "/repos/:owner/:repo")
        .sub(%r{\A/users/[^/]+}, "/users/:username")
        .sub(%r{/commits/[0-9a-f]{7,40}\z}, "/commits/:sha")
    rescue URI::InvalidURIError
      "invalid"
    end

    private_class_method :record_response, :rate_limit_from, :endpoint_template, :token_fingerprint

    def repository_exists?
      return nil unless user.github_access_token.present?

      response = self.class.get("https://api.github.com/repos/#{owner}/#{repo}", token: user.github_access_token)

      case response.status.code
      when 200 then true
      when 404 then false
      else
        Rails.logger.warn "[#{self.class.name}] Could not verify #{owner}/#{repo}: #{response.status}"
        nil
      end
    rescue HTTP::Error, OpenSSL::SSL::SSLError, RateLimitError => e
      Rails.logger.warn "[#{self.class.name}] Could not verify #{owner}/#{repo}: #{e.message}"
      nil
    end

    def fetch_repo_metadata
      return nil unless user.github_access_token.present?

      # Fetch basic repository info
      repo_data = fetch_repository_info
      # Only public repositories are synced; private metadata could otherwise
      # appear on public profiles.
      return nil if repo_data.nil? || repo_data["private"]

      languages_data = fetch_languages
      commit_count, last_commit_at = fetch_commit_stats(repo_data["default_branch"])

      {
        stars: repo_data["stargazers_count"],
        description: repo_data["description"],
        language: repo_data["language"],
        languages: languages_data&.keys&.join(", "),
        homepage: repo_data["homepage"].presence&.then { |hp| hp.match?(Repository::HOMEPAGE_FORMAT) ? hp : nil },
        commit_count: commit_count,
        last_commit_at: last_commit_at&.then { |date| Time.parse(date) },
        last_synced_at: Time.current
      }
    end

    private

    def make_api_request(url)
      handle_response(self.class.get(url, token: user.github_access_token))
    end

    def fetch_repository_info
      make_api_request("https://api.github.com/repos/#{owner}/#{repo}")
    end

    def fetch_languages
      make_api_request("https://api.github.com/repos/#{owner}/#{repo}/languages")
    end

    # Returns the commit count and the latest commit date from one request.
    # GitHub has no commit count field, so the count is the last page number
    # of a per_page=1 listing, and that page's only commit is the newest.
    def fetch_commit_stats(default_branch = nil)
      branch_param = default_branch ? "&sha=#{default_branch}" : ""
      url = "https://api.github.com/repos/#{owner}/#{repo}/commits?per_page=1#{branch_param}"
      response = self.class.get(url, token: user.github_access_token)

      case response.status.code
      when 200
        latest = response.parse.first&.dig("commit", "committer", "date")
        link_header = response.headers["Link"]
        if link_header && (match = link_header.match(/.*page=(\d+)[^>]*>;\s*rel="last"/))
          [ match[1].to_i, latest ]
        else
          [ 1, latest ]
        end
      when 404, 409
        # 409 means the repository is empty.
        [ 0, nil ]
      when 500..599
        # Raising keeps the stored count and latest commit instead of
        # overwriting them with 0 and nil.
        raise ServerError, "GitHub returned #{response.status} for #{owner}/#{repo} commits"
      else
        Rails.logger.warn "[#{self.class.name}] Failed to fetch commit count for #{owner}/#{repo}: #{response.status}"
        [ 0, nil ]
      end
    end
  end
end
