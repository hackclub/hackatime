class SyncStaleRepoMetadataJob < ApplicationJob
  queue_as :default

  BATCH_DELAY = 5.seconds

  def perform
    Rails.logger.info "[SyncStaleRepoMetadataJob] Starting sync of stale repository metadata"

    # Fix orphaned mappings (nil repository) first
    ProjectRepoMapping.where(repository: nil).where.not(repo_url: [ nil, "" ]).find_each do |mapping|
      mapping.update!(repository: Repository.find_or_create_by_url(mapping.repo_url))
    rescue => e
      report_error(e, message: "[SyncStaleRepoMetadataJob] Failed to create repository for mapping #{mapping.id}")
    end

    stale_repos = Repository.where("last_synced_at IS NULL OR last_synced_at < ?", 1.day.ago).joins(:users).distinct
    count = stale_repos.count
    Rails.logger.info "[SyncStaleRepoMetadataJob] Enqueuing sync for #{count} stale repositories"

    # Stagger to avoid thundering herd / rate limit exhaustion
    stale_repos.find_each.with_index do |repository, index|
      SyncRepoMetadataJob.set(wait: index * BATCH_DELAY).perform_later(repository.id)
    end

    Rails.logger.info "[SyncStaleRepoMetadataJob] Completed enqueuing #{count} sync jobs"
  end
end
