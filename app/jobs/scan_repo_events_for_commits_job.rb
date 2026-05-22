class ScanRepoEventsForCommitsJob < ApplicationJob
  queue_as :literally_whenever

  include GoodJob::ActiveJobExtensions::Concurrency
  good_job_control_concurrency_with(total_limit: 1, key: -> { self.class.name }, drop: true)

  COMMITS_BATCH_SIZE = 1000

  def perform
    Rails.logger.info "[ScanRepoEventsForCommitsJob] Starting scan of RepoHostEvents for new commits."

    buffer = []
    repository_id_cache = {}
    RepoHostEvent
      .where(provider: RepoHostEvent.providers[:github])
      .where("raw_event_payload->>'type' = ?", "PushEvent")
      .where("created_at >= ?", 90.days.ago)
      .order(created_at: :desc)
      .find_each(batch_size: 100) do |event|
      user = event.user
      unless user
        Rails.logger.warn "[ScanRepoEventsForCommitsJob] Event ID #{event.id} has no associated user. Skipping."
        next
      end

      commits_data = event.raw_event_payload.dig("payload", "commits")
      next unless commits_data.is_a?(Array) && commits_data.any?

      commits_data.each do |info|
        sha = info["sha"]
        api_url = info["url"]
        if sha.blank? || api_url.blank?
          Rails.logger.warn "[ScanRepoEventsForCommitsJob] Event ID #{event.id} (User ##{user.id}) has a commit with missing SHA or API URL. Info: #{info.inspect}"
          next
        end

        repository_id = nil
        if api_url =~ %r{https://api\.github\.com/repos/([^/]+)/([^/]+)/commits/}
          repo_url = "https://github.com/#{$1}/#{$2}"
          repository_id = repository_id_cache.fetch(repo_url) { repository_id_cache[repo_url] = Repository.find_by(url: repo_url)&.id }
        end

        buffer << { sha:, api_url:, user_id: user.id, provider: event.provider.to_s, repository_id: }
      end

      if buffer.size >= COMMITS_BATCH_SIZE
        process_commits_buffer(buffer)
        buffer.clear
      end
    rescue JSON::ParserError => e
      report_error(e, message: "[ScanRepoEventsForCommitsJob] Failed to parse raw_event_payload for Event ID #{event.id}")
    rescue => e
      report_error(e, message: "[ScanRepoEventsForCommitsJob] Error processing Event ID #{event.id}")
    end

    process_commits_buffer(buffer) unless buffer.empty?
    Rails.logger.info "[ScanRepoEventsForCommitsJob] Finished scan."
  end

  private

  def process_commits_buffer(commits)
    return if commits.empty?
    existing = Commit.where(sha: commits.map { |c| c[:sha] }.uniq).pluck(:sha).to_set
    enqueued = 0

    commits.each do |c|
      next if existing.include?(c[:sha])
      Rails.logger.info "[ScanRepoEventsForCommitsJob] Enqueuing ProcessCommitJob for SHA #{c[:sha]}, User ##{c[:user_id]}, Provider #{c[:provider]}."
      ProcessCommitJob.perform_later(c[:user_id], c[:sha], c[:api_url], c[:provider], c[:repository_id])
      enqueued += 1
    end

    Rails.logger.info "[ScanRepoEventsForCommitsJob] Processed buffer of #{commits.size} potential commits. Enqueued #{enqueued} new ProcessCommitJob(s)."
  end
end
