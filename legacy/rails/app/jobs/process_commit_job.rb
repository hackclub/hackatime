require "json"

class ProcessCommitJob < ApplicationJob
  include GithubApiJob

  queue_as :literally_whenever

  def perform(user_id, commit_sha, commit_api_url, provider_string, repository_id = nil)
    provider_sym = provider_string.to_sym
    user = User.find_by(id: user_id)
    repository = repository_id ? Repository.find_by(id: repository_id) : nil

    unless user
      Rails.logger.warn "[ProcessCommitJob] User ##{user_id} not found. Skipping commit #{commit_sha}."
      return
    end

    if Commit.exists?(sha: commit_sha)
      return
    end

    Rails.logger.info "[ProcessCommitJob] Processing commit #{commit_sha} for User ##{user_id} via #{provider_sym} from URL: #{commit_api_url}"

    case provider_sym
    when :github
      process_github_commit(user, commit_sha, commit_api_url, repository)
    else
      report_message("[ProcessCommitJob] Unknown provider '#{provider_sym}' for commit #{commit_sha}.")
    end
  end

  private

  def process_github_commit(user, commit_sha, commit_api_url, repository)
    unless user.github_access_token.present?
      Rails.logger.warn "[ProcessCommitJob] User ##{user.id} missing GitHub token for commit #{commit_sha}. Skipping."
      return
    end

    response = nil
    begin
      response = github_client(user).get(commit_api_url)

      if response.status.success?
        commit_data_json = response.parse

        api_commit_sha = commit_data_json["sha"]
        unless api_commit_sha == commit_sha
          report_message("[ProcessCommitJob] SHA mismatch for User ##{user.id}. Expected #{commit_sha}, API returned #{api_commit_sha}. URL: #{commit_api_url}")
          return
        end

        committer_date_str = commit_data_json.dig("commit", "committer", "date")
        unless committer_date_str
          report_message("[ProcessCommitJob] Committer date not found in API response for commit #{commit_sha}.")
          return
        end

        begin
          commit_actual_created_at = Time.zone.parse(committer_date_str)
        rescue ArgumentError => e
          report_error(e, message: "[ProcessCommitJob] Invalid committer date format '#{committer_date_str}' for commit #{commit_sha}.")
          return
        end

        Commit.find_or_create_by(sha: api_commit_sha) do |c|
          c.user_id = user.id
          c.repository_id = repository&.id
          c.github_raw = sanitize_json_data(commit_data_json)
          c.created_at = commit_actual_created_at
          c.updated_at = Time.current
        end
        Rails.logger.info "[ProcessCommitJob] Successfully processed commit #{api_commit_sha} for User ##{user.id}."

      elsif response.status.code == 401
        report_message("[ProcessCommitJob] Unauthorized (401) for User ##{user.id}. GitHub token expired/invalid. URL: #{commit_api_url}")
        user.update!(github_access_token: nil)
        Rails.logger.info "[ProcessCommitJob] Cleared invalid GitHub token for User ##{user.id}. User will need to re-authenticate."
      elsif response.status.code == 404
        Rails.logger.warn "[ProcessCommitJob] Commit #{commit_sha} not found (404) at #{commit_api_url} for User ##{user.id}."
      elsif response.status.code == 403
        return if handle_github_rate_limit(response, user.id, commit_sha, commit_api_url, "github", repository&.id)
        report_message("[ProcessCommitJob] GitHub API forbidden (403) for User ##{user.id}. URL: #{commit_api_url}. Response: #{response.body.to_s.truncate(500)}")
      else
        report_message("[ProcessCommitJob] GitHub API error for User ##{user.id}. Status: #{response.status}. URL: #{commit_api_url}. Response: #{response.body.to_s.truncate(500)}")
        raise "GitHub API Error: Status #{response.status}" if response.status.server_error?
      end

    rescue HTTP::Error => e
      report_error(e, message: "[ProcessCommitJob] HTTP Error fetching commit #{commit_sha} for User ##{user.id}. URL: #{commit_api_url}")
      raise
    rescue JSON::ParserError => e
      report_error(e, message: "[ProcessCommitJob] JSON Parse Error for commit #{commit_sha} (User ##{user.id}). URL: #{commit_api_url}. Body: #{response&.body&.to_s&.truncate(200)}")
    rescue ActiveRecord::RecordInvalid => e
      report_error(e, message: "[ProcessCommitJob] Validation failed for commit #{commit_sha} (User ##{user.id})")
    end
  end

  def sanitize_json_data(data)
    json_string = data.to_json
    sanitized_string = json_string.gsub(/\\u0000/, "")
    JSON.parse(sanitized_string)
  rescue JSON::ParserError => e
    Rails.logger.warn "[ProcessCommitJob] Failed to sanitize JSON data: #{e.message}. Falling back to original data."
    data
  end
end
