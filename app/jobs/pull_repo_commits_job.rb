require "http"

class PullRepoCommitsJob < ApplicationJob
  queue_as :literally_whenever

  # Retry on common network issues or temporary API errors
  retry_on HTTP::TimeoutError, HTTP::ConnectionError, wait: :exponentially_longer, attempts: 5
  retry_on JSON::ParserError, wait: 10.seconds, attempts: 3 # If API returns malformed JSON

  discard_on ActiveJob::DeserializationError # If User record is gone

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

    # Find the repository record
    repo_url = "https://github.com/#{owner}/#{repo}"
    repository = Repository.find_by(url: repo_url)

    Rails.logger.info "[PullRepoCommitsJob] Pulling commits for #{owner}/#{repo} for User ##{user.id} (Repository: #{repository&.id})"

    # Get commits from the last 3 days
    since_date = 3.days.ago.iso8601
    api_url = "https://api.github.com/repos/#{owner}/#{repo}/commits?since=#{since_date}"

    begin
      response = HTTP.headers(
        "Accept" => "application/vnd.github.v3+json",
        "Authorization" => "Bearer #{user.github_access_token}",
        "X-GitHub-Api-Version" => "2022-11-28"
      ).timeout(connect: 5, read: 10).get(api_url)

      if response.status.success?
        commits_data = response.parse
        process_commits(user, commits_data, repository)

      elsif response.status.code == 401 # Unauthorized
        Rails.logger.error "[PullRepoCommitsJob] Unauthorized (401) for User ##{user.id}. GitHub token expired/invalid. URL: #{api_url}"
        user.update!(github_access_token: nil)
        Rails.logger.info "[PullRepoCommitsJob] Cleared invalid GitHub token for User ##{user.id}. User will need to re-authenticate."
      elsif response.status.code == 404
        Rails.logger.warn "[PullRepoCommitsJob] Repository #{owner}/#{repo} not found (404) for User ##{user.id}."
      elsif response.status.code == 403 # Forbidden, could be rate limit or permissions
        if response.headers["X-RateLimit-Remaining"].to_i == 0
          reset_time = Time.at(response.headers["X-RateLimit-Reset"].to_i)
          delay_seconds = [ (reset_time - Time.current).ceil, 5 ].max # at least 5s delay
          Rails.logger.warn "[PullRepoCommitsJob] GitHub API rate limit exceeded for User ##{user.id}. Retrying in #{delay_seconds}s."
          self.class.set(wait: delay_seconds.seconds).perform_later(user.id, owner, repo)
        else
          Rails.logger.error "[PullRepoCommitsJob] GitHub API forbidden (403) for User ##{user.id}. Response: #{response.body.to_s.truncate(500)}"
        end
      else
        Rails.logger.error "[PullRepoCommitsJob] GitHub API error for User ##{user.id}. Status: #{response.status}. Response: #{response.body.to_s.truncate(500)}"
        raise "GitHub API Error: Status #{response.status}" if response.status.server_error?
      end

    rescue HTTP::Error => e
      Rails.logger.error "[PullRepoCommitsJob] HTTP Error fetching commits for #{owner}/#{repo} (User ##{user.id}): #{e.message}"
      raise # Re-raise to allow GoodJob to retry based on retry_on
    rescue JSON::ParserError => e
      Rails.logger.error "[PullRepoCommitsJob] JSON Parse Error for #{owner}/#{repo} (User ##{user.id}): #{e.message}"
      raise # Re-raise to allow GoodJob to retry based on retry_on
    end
  end

  private

  def process_commits(user, commits_data, repository)
    return if commits_data.empty?

    # Get existing commit SHAs to avoid duplicates
    shas_to_check = commits_data.map { |c| c["sha"] }.uniq
    existing_shas = Commit.where(sha: shas_to_check).pluck(:sha).to_set

    processed_count = 0
    enqueued_count = 0

    commits_data.each do |commit_data|
      processed_count += 1
      commit_sha = commit_data["sha"]
      commit_api_url = commit_data["url"]

      # Skip if commit already exists
      next if existing_shas.include?(commit_sha)

      # Get detailed commit info to check author
      begin
        commit_response = HTTP.headers(
          "Accept" => "application/vnd.github.v3+json",
          "Authorization" => "Bearer #{user.github_access_token}",
          "X-GitHub-Api-Version" => "2022-11-28"
        ).timeout(connect: 5, read: 10).get(commit_api_url)

        if commit_response.status.success?
          commit_details = commit_response.parse
          author = commit_details.dig("author")

          # Check both author ID and login
          author_id = author&.dig("id")
          author_login = author&.dig("login")

          # Process if either the ID or login matches
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
        Rails.logger.error "[PullRepoCommitsJob] HTTP Error fetching commit details for #{commit_sha}: #{e.message}"
        next
      rescue JSON::ParserError => e
        Rails.logger.error "[PullRepoCommitsJob] JSON Parse Error for commit details #{commit_sha}: #{e.message}"
        next
      end
    end

    Rails.logger.info "[PullRepoCommitsJob] Processed #{processed_count} commits. Enqueued #{enqueued_count} new ProcessCommitJob(s)."
  end
end
