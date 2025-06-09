require "http"
require "json"

class ProcessCommitJob < ApplicationJob
  queue_as :literally_whenever

  # Retry on common network issues or temporary API errors
  retry_on HTTP::TimeoutError, HTTP::ConnectionError, wait: :exponentially_longer, attempts: 5
  retry_on JSON::ParserError, wait: 10.seconds, attempts: 3 # If API returns malformed JSON

  discard_on ActiveJob::DeserializationError # If User record is gone

  def perform(user_id, commit_sha, commit_api_url, provider_string, repository_id = nil)
    provider_sym = provider_string.to_sym # Convert string back to symbol
    user = User.find_by(id: user_id)
    repository = repository_id ? Repository.find_by(id: repository_id) : nil

    unless user
      Rails.logger.warn "[ProcessCommitJob] User ##{user_id} not found. Skipping commit #{commit_sha}."
      return
    end

    # Idempotency: Check if commit already exists
    if Commit.exists?(sha: commit_sha)
      # Rails.logger.info "[ProcessCommitJob] Commit #{commit_sha} already exists. Skipping."
      # Optionally, you could update provider-specific raw data here if it's from a different provider
      # and the commit record already exists (e.g., adding gitlab_raw to an existing commit)
      return
    end

    Rails.logger.info "[ProcessCommitJob] Processing commit #{commit_sha} for User ##{user_id} via #{provider_sym} from URL: #{commit_api_url}"

    case provider_sym
    when :github
      process_github_commit(user, commit_sha, commit_api_url, repository)
    # Add other providers like :gitlab later
    # when :gitlab
    #   process_gitlab_commit(user, commit_sha, commit_api_url, repository)
    else
      Rails.logger.error "[ProcessCommitJob] Unknown provider '#{provider_sym}' for commit #{commit_sha}."
    end
  end

  private

  def process_github_commit(user, commit_sha, commit_api_url, repository)
    unless user.github_access_token.present?
      Rails.logger.warn "[ProcessCommitJob] User ##{user.id} missing GitHub token for commit #{commit_sha}. Skipping."
      return
    end

    begin
      response = HTTP.headers(
        "Accept" => "application/vnd.github.v3+json",
        "Authorization" => "Bearer #{user.github_access_token}",
        "X-GitHub-Api-Version" => "2022-11-28"
      ).timeout(connect: 5, read: 10).get(commit_api_url)

      if response.status.success?
        commit_data_json = response.parse

        api_commit_sha = commit_data_json["sha"]
        unless api_commit_sha == commit_sha
          Rails.logger.error "[ProcessCommitJob] SHA mismatch for User ##{user.id}. Expected #{commit_sha}, API returned #{api_commit_sha}. URL: #{commit_api_url}"
          return # Critical data integrity issue
        end

        committer_date_str = commit_data_json.dig("commit", "committer", "date")
        unless committer_date_str
          Rails.logger.error "[ProcessCommitJob] Committer date not found in API response for commit #{commit_sha}. Data: #{commit_data_json.inspect}"
          return
        end

        begin
          # API dates are typically ISO8601 (UTC). Time.zone.parse respects the application's zone.
          # It's good practice to store in UTC, which parse will do correctly for ISO8601.
          commit_actual_created_at = Time.zone.parse(committer_date_str)
        rescue ArgumentError
          Rails.logger.error "[ProcessCommitJob] Invalid committer date format '#{committer_date_str}' for commit #{commit_sha}."
          return
        end

        commit = Commit.find_or_create_by(sha: api_commit_sha) do |c|
          c.user_id = user.id
          c.repository_id = repository&.id
          c.github_raw = commit_data_json
          c.created_at = commit_actual_created_at
          c.updated_at = Time.current
        end
        Rails.logger.info "[ProcessCommitJob] Successfully processed commit #{api_commit_sha} for User ##{user.id}."

      elsif response.status.code == 401 # Unauthorized
        Rails.logger.error "[ProcessCommitJob] Unauthorized (401) for User ##{user.id}. GitHub token expired/invalid. URL: #{commit_api_url}"
        user.update!(github_access_token: nil)
        Rails.logger.info "[ProcessCommitJob] Cleared invalid GitHub token for User ##{user.id}. User will need to re-authenticate."
      elsif response.status.code == 404
        Rails.logger.warn "[ProcessCommitJob] Commit #{commit_sha} not found (404) at #{commit_api_url} for User ##{user.id}."
      elsif response.status.code == 403 # Forbidden, could be rate limit or permissions
        if response.headers["X-RateLimit-Remaining"].to_i == 0
          reset_time = Time.at(response.headers["X-RateLimit-Reset"].to_i)
          delay_seconds = [ (reset_time - Time.current).ceil, 5 ].max # at least 5s delay
          Rails.logger.warn "[ProcessCommitJob] GitHub API rate limit exceeded for User ##{user.id}. Retrying in #{delay_seconds}s. URL: #{commit_api_url}"
          self.class.set(wait: delay_seconds.seconds).perform_later(user.id, commit_sha, commit_api_url, "github", repository&.id)
        else
          Rails.logger.error "[ProcessCommitJob] GitHub API forbidden (403) for User ##{user.id}. URL: #{commit_api_url}. Response: #{response.body.to_s.truncate(500)}"
        end
      else
        Rails.logger.error "[ProcessCommitJob] GitHub API error for User ##{user.id}. Status: #{response.status}. URL: #{commit_api_url}. Response: #{response.body.to_s.truncate(500)}"
        raise "GitHub API Error: Status #{response.status}" if response.status.server_error? # Trigger retry for server errors
      end

    rescue HTTP::Error => e # Covers TimeoutError, ConnectionError
      Rails.logger.error "[ProcessCommitJob] HTTP Error fetching commit #{commit_sha} for User ##{user.id}: #{e.message}. URL: #{commit_api_url}"
      raise # Re-raise to allow GoodJob to retry based on retry_on
    rescue JSON::ParserError => e
      Rails.logger.error "[ProcessCommitJob] JSON Parse Error for commit #{commit_sha} (User ##{user.id}): #{e.message}. URL: #{commit_api_url}. Body: #{response&.body&.to_s&.truncate(200)}"
      # Malformed JSON usually isn't temporary, so might not retry unless API is known to be flaky.
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[ProcessCommitJob] Validation failed for commit #{commit_sha} (User ##{user.id}): #{e.message}"
    end
  end
end
