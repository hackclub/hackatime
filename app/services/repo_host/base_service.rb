module RepoHost
  class BaseService
    def initialize(user, repo_url)
      @user = user
      @repo_url = repo_url
      @owner, @repo = parse_repo_url(repo_url)
    end

    def fetch_repo_metadata
      raise NotImplementedError, "Subclasses must implement fetch_repo_metadata"
    end

    private

    attr_reader :user, :repo_url, :owner, :repo

    def parse_repo_url(url)
      # Extract owner and repo from URL
      # Example: https://github.com/owner/repo -> ["owner", "repo"]
      # Example: https://gitlab.com/owner/repo -> ["owner", "repo"]
      if url =~ %r{https?://[^/]+/([^/]+)/([^/]+)/?$}
        [ $1, $2 ]
      else
        raise ArgumentError, "Invalid repository URL format: #{url}"
      end
    end

    def api_headers
      raise NotImplementedError, "Subclasses must implement api_headers"
    end

    def make_api_request(url)
      response = HTTP.headers(api_headers)
                     .timeout(connect: 5, read: 10)
                     .get(url)

      handle_response(response)
    end

    def handle_response(response)
      case response.status.code
      when 200
        response.parse
      when 403
        handle_rate_limit(response)
      when 404
        Rails.logger.warn "[#{self.class.name}] Repository #{owner}/#{repo} not found (404)"
        nil
      else
        Rails.logger.error "[#{self.class.name}] API error. Status: #{response.status}"
        nil
      end
    end

    def handle_rate_limit(response)
      if response.headers["X-RateLimit-Remaining"]&.to_i == 0
        reset_time = Time.at(response.headers["X-RateLimit-Reset"].to_i)
        delay_seconds = [ (reset_time - Time.current).ceil, 5 ].max
        Rails.logger.warn "[#{self.class.name}] Rate limit exceeded. Reset in #{delay_seconds}s"
      end
      nil
    end
  end
end
