module RepoHost
  class RateLimitError < StandardError; end

  class BaseService < ApplicationService
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
      uri = URI.parse(url)
      path_parts = uri.path.to_s.split("/").reject(&:blank?)

      raise ArgumentError, "Invalid repository URL format: #{url}" if uri.host.blank? || path_parts.size < 2

      [ path_parts[0...-1].join("/"), path_parts.last ]
    rescue URI::InvalidURIError
      raise ArgumentError, "Invalid repository URL format: #{url}"
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
      when 403, 429
        handle_rate_limit(response)
      when 404
        Rails.logger.warn "[#{self.class.name}] Repository #{owner}/#{repo} not found (404)"
        nil
      else
        report_message("[#{self.class.name}] API error. Status: #{response.status}")
        nil
      end
    end

    def handle_rate_limit(response)
      remaining = response.headers["X-RateLimit-Remaining"] || response.headers["RateLimit-Remaining"]
      reset_at = response.headers["X-RateLimit-Reset"] || response.headers["RateLimit-Reset"]

      if remaining&.to_i == 0 && reset_at.present?
        reset_time = Time.at(reset_at.to_i)
        delay_seconds = [ (reset_time - Time.current).ceil, 5 ].max
        raise RateLimitError, "Rate limit exceeded for #{owner}/#{repo}. Reset in #{delay_seconds}s"
      end
      nil
    end
  end
end
