module RepoHost
  class ServiceFactory
    def self.for_url(user, repo_url)
      case repo_url
      when %r{github\.com}
        GithubService.new(user, repo_url)
      when %r{gitlab\.com}
        GitlabService.new(user, repo_url)
      else
        raise ArgumentError, "Unsupported repository host: #{repo_url}. Currently only GitHub and GitLab are supported."
      end
    end

    def self.supported_hosts
      %w[github.com gitlab.com]
    end

    def self.host_for_url(repo_url)
      uri = URI.parse(repo_url)
      uri.host
    rescue URI::InvalidURIError
      nil
    end
  end
end
