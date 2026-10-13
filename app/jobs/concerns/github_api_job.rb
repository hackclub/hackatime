require "http"

module GithubApiJob
  extend ActiveSupport::Concern

  included do
    retry_on HTTP::TimeoutError, HTTP::ConnectionError, wait: :polynomially_longer, attempts: 5
    retry_on JSON::ParserError, wait: 10.seconds, attempts: 3
    # RepoHost::GithubService pauses a rate limited token, so retries during the
    # pause do not reach GitHub.
    retry_on RepoHost::RateLimitError, wait: 15.minutes, attempts: 3
  end
end
