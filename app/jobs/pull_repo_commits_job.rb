class PullRepoCommitsJob < ApplicationJob
  include GithubApiJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :literally_whenever

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "pull_repo_commits_#{arguments.join('/')}" }
  )

  LOOKBACK = 3.days

  # Stores the user's own recent commits from a single list request. The list
  # response already carries the author and commit dates, so no per-commit
  # requests are made.
  def perform(user_id, owner, repo)
    user = User.find_by(id: user_id)
    return unless user&.github_access_token.present? && user.github_uid.present? && user.github_username.present?

    repository = Repository.find_by(url: "https://github.com/#{owner}/#{repo}")
    query = { author: user.github_username, since: LOOKBACK.ago.iso8601, per_page: 100 }.to_query
    response = RepoHost::GithubService.get(
      "https://api.github.com/repos/#{owner}/#{repo}/commits?#{query}",
      token: user.github_access_token
    )

    case response.status.code
    when 200
      store_commits(user, repository, response.parse)
    when 401
      # Only the token is cleared. github_uid stays, so leaderboard eligibility
      # and the account link are unaffected.
      user.update!(github_access_token: nil)
      Rails.logger.info "[PullRepoCommitsJob] Cleared invalid GitHub token for User ##{user.id}"
    when 404, 409
      # Missing or inaccessible repository (404) or an empty repository (409).
      nil
    else
      raise "GitHub API Error: Status #{response.status}" if response.status.server_error?
      report_message("[PullRepoCommitsJob] GitHub API error for User ##{user.id}. Status: #{response.status}")
    end
  end

  private

  def store_commits(user, repository, commits)
    now = Time.current
    rows = commits.filter_map do |commit|
      next unless authored_by?(commit, user)
      committed_at = commit.dig("commit", "committer", "date")
      next if commit["sha"].blank? || committed_at.blank?

      {
        sha: commit["sha"],
        user_id: user.id,
        repository_id: repository&.id,
        github_raw: without_null_bytes(commit),
        created_at: Time.zone.parse(committed_at),
        updated_at: now
      }
    end

    Commit.insert_all(rows) if rows.any?
  end

  def authored_by?(commit, user)
    author = commit["author"] || {}
    author["id"].to_s == user.github_uid.to_s || author["login"] == user.github_username
  end

  def without_null_bytes(data)
    JSON.parse(data.to_json.gsub("\\u0000", ""))
  end
end
