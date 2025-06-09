class ScanRepoEventsForCommitsJob < ApplicationJob
  queue_as :literally_whenever

  include GoodJob::ActiveJobExtensions::Concurrency
  good_job_control_concurrency_with(
    total_limit: 1, # Only one instance of this job should run at a time
    key: -> { self.class.name },
    drop: true # If another instance is running or queued, drop this one
  )

  COMMITS_BATCH_SIZE = 1000 # Number of commits to check for existence in the DB at a time

  def perform
    Rails.logger.info "[ScanRepoEventsForCommitsJob] Starting scan of RepoHostEvents for new commits."

    # Determine the lookback window. Consider events from the last N days.
    # If you have a way to track processed events (e.g., a new column on RepoHostEvent),
    # you could use that. For now, we'll use a time window and rely on Commit.exists?
    # to avoid re-processing.
    time_window_start = 90.days.ago
    potential_commits_buffer = []

    # Process events in batches to manage memory
    # Filter for GitHub PushEvents initially
    RepoHostEvent
      .where(provider: RepoHostEvent.providers[:github])
      .where("raw_event_payload->>'type' = ?", "PushEvent") # Efficiently query JSONB
      .where("created_at >= ?", time_window_start) # Focus on recent events
      .order(created_at: :desc) # Process newer events first, potentially stopping earlier
      .find_each(batch_size: 100) do |event|
      user = event.user
      unless user
        Rails.logger.warn "[ScanRepoEventsForCommitsJob] Event ID #{event.id} has no associated user. Skipping."
        next
      end

      payload = event.raw_event_payload
      # Safely access nested commit data from the JSON payload
      commits_data = payload.dig("payload", "commits")

      unless commits_data.is_a?(Array) && commits_data.any?
        # Rails.logger.debug "[ScanRepoEventsForCommitsJob] Event ID #{event.id} (User ##{user.id}) is a PushEvent but has no commits. Skipping."
        next
      end

      commits_data.each do |commit_info|
        commit_sha = commit_info["sha"]
        # The 'url' in the PushEvent's commit object is the API URL for that commit
        commit_api_url = commit_info["url"]

        if commit_sha.blank? || commit_api_url.blank?
          Rails.logger.warn "[ScanRepoEventsForCommitsJob] Event ID #{event.id} (User ##{user.id}) has a commit with missing SHA or API URL. Info: #{commit_info.inspect}"
          next
        end

        # Extract repository info from commit API URL
        # Format: https://api.github.com/repos/owner/repo/commits/sha
        repository_id = nil
        if commit_api_url =~ %r{https://api\.github\.com/repos/([^/]+)/([^/]+)/commits/}
          owner = $1
          repo = $2
          repo_url = "https://github.com/#{owner}/#{repo}"
          repository = Repository.find_by(url: repo_url)
          repository_id = repository&.id
        end

        potential_commits_buffer << {
          sha: commit_sha,
          api_url: commit_api_url,
          user_id: user.id,
          provider: event.provider.to_s,
          repository_id: repository_id
        }
      end

      # If the buffer is full, process it
      if potential_commits_buffer.size >= COMMITS_BATCH_SIZE
        process_commits_buffer(potential_commits_buffer)
        potential_commits_buffer.clear
      end
    rescue JSON::ParserError => e
      Rails.logger.error "[ScanRepoEventsForCommitsJob] Failed to parse raw_event_payload for Event ID #{event.id}: #{e.message}"
    rescue => e # Catch other potential errors during event processing
      Rails.logger.error "[ScanRepoEventsForCommitsJob] Error processing Event ID #{event.id}: #{e.message}\n#{e.backtrace.take(5).join("\n")}"
    end

    # Process any remaining commits in the buffer
    process_commits_buffer(potential_commits_buffer) unless potential_commits_buffer.empty?

    Rails.logger.info "[ScanRepoEventsForCommitsJob] Finished scan."
  end

  private

  def process_commits_buffer(commits_to_check)
    return if commits_to_check.empty?

    # Extract all SHAs from the buffer
    shas_to_check = commits_to_check.map { |c| c[:sha] }.uniq

    # Find which SHAs already exist in the database with a single query
    existing_shas = Commit.where(sha: shas_to_check).pluck(:sha).to_set

    processed_count = 0
    enqueued_count = 0

    # Process each commit in the buffer
    commits_to_check.each do |commit_details|
      processed_count += 1
      unless existing_shas.include?(commit_details[:sha])
        Rails.logger.info "[ScanRepoEventsForCommitsJob] Enqueuing ProcessCommitJob for SHA #{commit_details[:sha]}, User ##{commit_details[:user_id]}, Provider #{commit_details[:provider]}."
        ProcessCommitJob.perform_later(
          commit_details[:user_id],
          commit_details[:sha],
          commit_details[:api_url],
          commit_details[:provider],
          commit_details[:repository_id]
        )
        enqueued_count += 1
      end
    end

    Rails.logger.info "[ScanRepoEventsForCommitsJob] Processed buffer of #{processed_count} potential commits. Enqueued #{enqueued_count} new ProcessCommitJob(s)."
  end
end
