class SyncRepoMetadataJob < ApplicationJob
  queue_as :literally_whenever

  retry_on HTTP::TimeoutError, HTTP::ConnectionError, wait: :exponentially_longer, attempts: 3
  retry_on JSON::ParserError, wait: 10.seconds, attempts: 2

  def perform(repository_id)
    repository = Repository.find_by(id: repository_id)
    return unless repository

    Rails.logger.info "[SyncRepoMetadataJob] Syncing metadata for #{repository.url}"

    begin
      # Use any user who has mapped to this repository for API access
      user = repository.users.joins(:project_repo_mappings).first
      return unless user

      service = RepoHost::ServiceFactory.for_url(user, repository.url)
      unless service
        Rails.logger.info "[SyncRepoMetadataJob] Unsupported repository host for #{repository.url}"
        return
      end

      metadata = service.fetch_repo_metadata

      if metadata
        repository.update!(metadata)
        Rails.logger.info "[SyncRepoMetadataJob] Updated metadata for #{repository.url}"
      else
        Rails.logger.warn "[SyncRepoMetadataJob] No metadata returned for #{repository.url}"
      end
    rescue => e
      Rails.logger.error "[SyncRepoMetadataJob] Unexpected error: #{e.message}"
      raise # Retry for other errors
    end
  end
end
