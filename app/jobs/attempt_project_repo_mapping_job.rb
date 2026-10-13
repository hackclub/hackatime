class AttemptProjectRepoMappingJob < ApplicationJob
  queue_as :latency_10s
  include HasEnqueueControl

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "attempt_project_repo_mapping_job_#{arguments.first}_#{arguments.last}" }
  )

  # How long a finished lookup (match or miss) suppresses new attempts.
  ATTEMPT_TTL = 14.days
  ORGS_TTL = 1.day
  # GitHub requests this job may make per user per day.
  DAILY_REQUEST_BUDGET = 50
  # GitHub repository names only contain these characters.
  REPO_NAME_FORMAT = /\A[A-Za-z0-9._-]{1,100}\z/

  class BudgetExhausted < StandardError; end

  def self.enqueue_for(user, project_name)
    return if ProjectRepoMapping::IGNORED_PROJECTS.include?(project_name)
    return unless user.github_uid.present? && user.github_access_token.present?

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
    return unless @user&.github_username.present? && @user.github_access_token.present?

    unless lookup_needed?
      remember_attempt
      return
    end

    repo_url = public_repo_url(@user.github_username) ||
      org_logins.lazy.filter_map { |org| public_repo_url(org) }.first
    create_mapping(repo_url) if repo_url
    remember_attempt
  rescue BudgetExhausted, RepoHost::RateLimitError => e
    # Leave the short enqueue key in place so a later heartbeat retries.
    Rails.logger.info "[AttemptProjectRepoMappingJob] Deferred lookup for User ##{user_id}: #{e.class.name}"
  end

  private

  def lookup_needed?
    return false if ProjectRepoMapping::IGNORED_PROJECTS.include?(@project_name)
    return false unless @project_name.match?(REPO_NAME_FORMAT)

    !@user.project_repo_mappings.exists?(project_name: @project_name)
  end

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
  rescue JSON::ParserError => e
    report_error(e, message: "Failed to parse GitHub repo response")
    nil
  end

  def org_logins
    Rails.cache.fetch("github_user_org_logins:#{@user.id}", expires_in: ORGS_TTL) do
      response = github_get("https://api.github.com/users/#{ERB::Util.url_encode(@user.github_username)}/orgs")
      next [] unless response.status.success?

      parsed = response.parse
      parsed.is_a?(Array) ? parsed.filter_map { |org| org["login"] } : []
    end
  rescue JSON::ParserError => e
    report_error(e, message: "Failed to parse GitHub orgs response")
    []
  end

  def github_get(url)
    raise BudgetExhausted unless spend_request_budget

    RepoHost::GithubService.get(url, token: @user.github_access_token)
  end

  def spend_request_budget
    key = "github_repo_mapping_requests:#{@user.id}:#{Date.current.iso8601}"
    count = Rails.cache.increment(key, 1, expires_in: 1.day)
    count.nil? || count <= DAILY_REQUEST_BUDGET
  end
end
