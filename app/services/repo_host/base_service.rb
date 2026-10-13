module RepoHost
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
      # https://github.com/owner/repo -> ["owner", "repo"]
      if url =~ %r{https?://[^/]+/([^/]+)/([^/]+)/?$}
        [ $1, $2 ]
      else
        raise ArgumentError, "Invalid repository URL format: #{url}"
      end
    end

    def make_api_request(url)
      raise NotImplementedError, "Subclasses must implement make_api_request"
    end

    def handle_response(response)
      case response.status.code
      when 200 then response.parse
      when 403
        Rails.logger.warn "[#{self.class.name}] Access to #{owner}/#{repo} forbidden (403)"
        nil
      when 404
        Rails.logger.warn "[#{self.class.name}] Repository #{owner}/#{repo} not found (404)"
        nil
      when 409
        # The repository exists but is empty, so it has no commits yet.
        nil
      when 500..599
        raise ServerError, "GitHub returned #{response.status} for #{owner}/#{repo}"
      else
        report_message("[#{self.class.name}] API error. Status: #{response.status}")
        nil
      end
    end
  end
end
