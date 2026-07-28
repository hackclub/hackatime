require "http"

module GithubApiJob
  extend ActiveSupport::Concern

  included do
    retry_on HTTP::TimeoutError, HTTP::ConnectionError, wait: :exponentially_longer, attempts: 5
    retry_on JSON::ParserError, wait: 10.seconds, attempts: 3
    discard_on ActiveJob::DeserializationError
  end

  private

  def github_client(user)
    RepoHost::GithubService.api_client(user.github_access_token)
  end

  def handle_github_rate_limit(response, *perform_args)
    return false unless response.status.code == 403 && response.headers["X-RateLimit-Remaining"].to_i == 0

    reset_time = Time.at(response.headers["X-RateLimit-Reset"].to_i)
    delay_seconds = [ (reset_time - Time.current).ceil, 5 ].max
    Rails.logger.warn "[#{self.class.name}] GitHub API rate limit exceeded. Retrying in #{delay_seconds}s."
    self.class.set(wait: delay_seconds.seconds).perform_later(*perform_args)
    true
  end
end
