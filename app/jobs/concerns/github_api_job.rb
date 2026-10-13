require "http"

module GithubApiJob
  extend ActiveSupport::Concern

  # Flipper flag that turns background GitHub sync on. While it is off, these
  # jobs finish without calling GitHub and no mapping lookups are queued.
  FLAG = :github_sync

  included do
    before_perform { throw :abort unless Flipper.enabled?(FLAG) }

    retry_on HTTP::TimeoutError, HTTP::ConnectionError, wait: :polynomially_longer, attempts: 5
    retry_on JSON::ParserError, wait: 10.seconds, attempts: 3
    # GitHub's primary limit window is an hour, so each retry runs after the
    # token's pause has ended. Retries during a pause would fail without
    # reaching GitHub and use up the attempts.
    retry_on RepoHost::RateLimitError, wait: 1.hour, attempts: 3
  end
end
