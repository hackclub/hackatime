class SyncStaleRepoMetadataJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SyncStaleRepoMetadataJob] Starting sync of stale repository metadata"

    # Find all mappings where the repository has stale metadata or is missing metadata entirely
    mappings_with_stale_repos = ProjectRepoMapping.includes(:repository, :user)
                                                  .joins(:repository)
                                                  .where("repositories.last_synced_at IS NULL OR repositories.last_synced_at < ?", 1.day.ago)

    # Also find mappings where repository is nil (shouldn't happen, but just in case)
    mappings_without_repos = ProjectRepoMapping.includes(:user)
                                               .where(repository: nil)

    all_stale_mappings = mappings_with_stale_repos.to_a + mappings_without_repos.to_a

    Rails.logger.info "[SyncStaleRepoMetadataJob] Found #{all_stale_mappings.count} project mappings with stale or missing repository metadata"

    # Group by repository to avoid duplicate API calls
    repos_to_sync = {}

    all_stale_mappings.each do |mapping|
      if mapping.repository
        repos_to_sync[mapping.repository.id] = mapping.repository
      else
        # Handle mappings without repository - recreate the repository
        Rails.logger.warn "[SyncStaleRepoMetadataJob] Found mapping without repository: #{mapping.inspect}"
        if mapping.repo_url.present?
          begin
            repo = Repository.find_or_create_by_url(mapping.repo_url)
            mapping.update!(repository: repo)
            repos_to_sync[repo.id] = repo
          rescue => e
            Rails.logger.error "[SyncStaleRepoMetadataJob] Failed to create repository for mapping #{mapping.id}: #{e.message}"
          end
        end
      end
    end

    Rails.logger.info "[SyncStaleRepoMetadataJob] Enqueuing sync for #{repos_to_sync.count} unique repositories"

    repos_to_sync.each_value do |repository|
      # Only sync if the repository has at least one user (needed for API access)
      next unless repository.users.exists?

      Rails.logger.info "[SyncStaleRepoMetadataJob] Enqueuing sync for #{repository.url}"
      SyncRepoMetadataJob.perform_later(repository.id)
    end

    Rails.logger.info "[SyncStaleRepoMetadataJob] Completed enqueuing sync jobs"
  end
end
