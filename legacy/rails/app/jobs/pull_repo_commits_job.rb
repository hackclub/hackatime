class PullRepoCommitsJob < ApplicationJob
  include GithubApiJob

  queue_as :literally_whenever

  def perform(user_id, owner, repo)
    user = User.find_by(id: user_id)

    unless user
      Rails.logger.warn "[PullRepoCommitsJob] User ##{user_id} not found. Skipping."
      return
    end

    unless user.github_access_token.present?
      Rails.logger.warn "[PullRepoCommitsJob] User ##{user.id} missing GitHub token. Skipping."
      return
    end

    repo_url = "https://github.com/#{owner}/#{repo}"
    repository = Repository.find_by(url: repo_url)

    Rails.logger.info "[PullRepoCommitsJob] Pulling commits for #{owner}/#{repo} for User ##{user.id} (Repository: #{repository&.id})"

    since_date = 3.days.ago.iso8601
    api_url = "https://api.github.com/repos/#{owner}/#{repo}/commits?since=#{since_date}"

    begin
      response = github_client(user).get(api_url)

      if response.status.success?
        process_commits(user, response.parse, repository)
      elsif response.status.code == 401
        report_message("[PullRepoCommitsJob] Unauthorized (401) for User ##{user.id}. GitHub token expired/invalid. URL: #{api_url}")
        user.update!(github_access_token: nil)
        Rails.logger.info "[PullRepoCommitsJob] Cleared invalid GitHub token for User ##{user.id}. User will need to re-authenticate."
      elsif response.status.code == 404
        Rails.logger.warn "[PullRepoCommitsJob] Repository #{owner}/#{repo} not found (404) for User ##{user.id}."
      elsif response.status.code == 403
        return if handle_github_rate_limit(response, user.id, owner, repo)
        report_message("[PullRepoCommitsJob] GitHub API forbidden (403) for User ##{user.id}. Response: #{response.body.to_s.truncate(500)}")
      else
        report_message("[PullRepoCommitsJob] GitHub API error for User ##{user.id}. Status: #{response.status}. Response: #{response.body.to_s.truncate(500)}")
        raise "GitHub API Error: Status #{response.status}" if response.status.server_error?
      end

    rescue HTTP::Error => e
      report_error(e, message: "[PullRepoCommitsJob] HTTP Error fetching commits for #{owner}/#{repo} (User ##{user.id})")
      raise
    rescue JSON::ParserError => e
      report_error(e, message: "[PullRepoCommitsJob] JSON Parse Error for #{owner}/#{repo} (User ##{user.id})")
      raise
    end
  end

  private

  def process_commits(user, commits_data, repository)
    return if commits_data.empty?

    shas_to_check = commits_data.map { |c| c["sha"] }.uniq
    existing_shas = Commit.where(sha: shas_to_check).pluck(:sha).to_set

    processed_count = 0
    enqueued_count = 0

    commits_data.each do |commit_data|
      processed_count += 1
      commit_sha = commit_data["sha"]
      commit_api_url = commit_data["url"]

      next if existing_shas.include?(commit_sha)

      begin
        commit_response = github_client(user).get(commit_api_url)

        if commit_response.status.success?
          commit_details = commit_response.parse
          author = commit_details.dig("author")

          author_id = author&.dig("id")
          author_login = author&.dig("login")

          if author_id == user.github_uid || author_login == user.github_username
            Rails.logger.info "[PullRepoCommitsJob] Enqueuing ProcessCommitJob for SHA #{commit_sha}, User ##{user.id}"
            ProcessCommitJob.perform_now(
              user.id,
              commit_sha,
              commit_api_url,
              "github",
              repository&.id
            )
            enqueued_count += 1
          else
            Rails.logger.debug "[PullRepoCommitsJob] Skipping commit #{commit_sha} - author ID #{author_id}/login #{author_login} doesn't match user ID #{user.github_uid}/login #{user.github_username}"
          end
        else
          Rails.logger.warn "[PullRepoCommitsJob] Failed to fetch commit details for #{commit_sha}: #{commit_response.status}"
        end
      rescue HTTP::Error => e
        report_error(e, message: "[PullRepoCommitsJob] HTTP Error fetching commit details for #{commit_sha}")
        next
      rescue JSON::ParserError => e
        report_error(e, message: "[PullRepoCommitsJob] JSON Parse Error for commit details #{commit_sha}")
        next
      end
    end

    Rails.logger.info "[PullRepoCommitsJob] Processed #{processed_count} commits. Enqueued #{enqueued_count} new ProcessCommitJob(s)."
  end
end
