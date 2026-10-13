require "http"

module GithubApiJob
  extend ActiveSupport::Concern

  included do
    retry_on HTTP::TimeoutError, HTTP::ConnectionError, wait: :polynomially_longer, attempts: 5
    retry_on JSON::ParserError, wait: 10.seconds, attempts: 3
    # GitHub's primary limit window is an hour, so each retry runs after the
    # token's pause has ended. Retries during a pause would fail without
    # reaching GitHub and use up the attempts.
    retry_on RepoHost::RateLimitError, wait: 1.hour, attempts: 3
  end
end
