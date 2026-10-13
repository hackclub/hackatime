class AttemptProjectRepoMappingJob < ApplicationJob
  queue_as :latency_10s
  include HasEnqueueControl
  include GithubApiJob

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "attempt_project_repo_mapping_job_#{arguments.first}_#{arguments.last}" }
  )

  # How long a finished lookup (match or miss) suppresses new attempts.
  ATTEMPT_TTL = 14.days
  ORGS_TTL = 1.day
  # GitHub requests this job may make per user per day.
  DAILY_REQUEST_BUDGET = 50
  # GitHub repository names only contain these characters and cannot be "." or "..".
  REPO_NAME_FORMAT = /\A(?!\.{1,2}\z)[A-Za-z0-9._-]{1,100}\z/

  # Raised when a lookup cannot finish now and must not be remembered as a miss.
  class Deferred < StandardError; end

  def self.enqueue_for(user, project_name)
    return unless project_name.to_s.match?(REPO_NAME_FORMAT)
    return unless user.github_uid.present? && user.github_access_token.present?
    return unless Flipper.enabled?(GithubApiJob::FLAG)

    Rails.cache.fetch(attempt_cache_key(user.id, project_name), expires_in: 1.hour) do
      perform_later(user.id, project_name)
      true
    end
  end

  def self.attempt_cache_key(user_id, project_name)
    "attempt_project_repo_mapping_job_#{user_id}_#{Digest::SHA256.hexdigest(project_name.to_s)}"
  end

  def perform(user_id, project_name)
    @user = User.find_by(id: user_id)
    @project_name = project_name
    return unless @project_name.to_s.match?(REPO_NAME_FORMAT)
    return unless @user&.github_username.present? && @user.github_access_token.present?

    unless @user.project_repo_mappings.exists?(project_name: @project_name)
      repo_url = public_repo_url(@user.github_username) || org_repo_url
      create_mapping(repo_url) if repo_url
    end
    remember_attempt
  rescue Deferred, RepoHost::RateLimitError => e
    # Leave the short enqueue key in place so a later heartbeat retries.
    Rails.logger.info "[AttemptProjectRepoMappingJob] Deferred lookup for User ##{user_id}: #{e.message}"
  end

  private

  def remember_attempt
    Rails.cache.write(self.class.attempt_cache_key(@user.id, @project_name), true, expires_in: ATTEMPT_TTL)
  end

  def create_mapping(repo_url)
    @user.project_repo_mappings.create!(project_name: @project_name, repo_url: repo_url)
  end

  # Only public repositories are mapped automatically.
  def public_repo_url(namespace)
    response = github_get("https://api.github.com/repos/#{ERB::Util.url_encode(namespace)}/#{@project_name}")
    return unless response.status.success?

    repo = response.parse
    repo["html_url"] unless repo["private"]
  end

  # A repository in one of the user's organisations is only mapped when the
  # user has commits in it and no other organisation has a matching one, so a
  # common name like "website" is not linked to the wrong organisation.
  def org_repo_url
    matches = org_logins.lazy.filter_map do |org|
      url = public_repo_url(org)
      url if url && authored_commits?(org)
    end.first(2)
    return matches.first if matches.one?

    Rails.logger.info "[AttemptProjectRepoMappingJob] Left User ##{@user.id} unmapped: ambiguous organisation match" if matches.many?
    nil
  end

  def authored_commits?(namespace)
    query = { author: @user.github_username, per_page: 1 }.to_query
    response = github_get("https://api.github.com/repos/#{ERB::Util.url_encode(namespace)}/#{@project_name}/commits?#{query}")
    response.status.success? && response.parse.any?
  end

  def org_logins
    Rails.cache.fetch("github_user_org_logins:#{@user.id}", expires_in: ORGS_TTL) do
      response = github_get("https://api.github.com/users/#{ERB::Util.url_encode(@user.github_username)}/orgs")
      response.status.success? ? response.parse.filter_map { |org| org["login"] } : []
    end
  end

  def github_get(url)
    raise Deferred, "daily GitHub request budget spent" unless spend_request_budget

    response = RepoHost::GithubService.get(url, token: @user.github_access_token)
    if response.status.unauthorized?
      # Only the token is cleared. github_uid stays, so leaderboard eligibility
      # and the account link are unaffected.
      @user.update!(github_access_token: nil)
      raise Deferred, "GitHub rejected the token"
    end
    raise Deferred, "GitHub returned #{response.status}" if response.status.server_error?

    response
  end

  def spend_request_budget
    key = "github_repo_mapping_requests:#{@user.id}:#{Date.current.iso8601}"
    count = Rails.cache.increment(key, 1, expires_in: 1.day)
    count.nil? || count <= DAILY_REQUEST_BUDGET
  end
end
