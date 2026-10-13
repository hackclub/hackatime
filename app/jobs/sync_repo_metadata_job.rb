class SyncRepoMetadataJob < ApplicationJob
  include GithubApiJob

  queue_as :literally_whenever

  def perform(repository_id)
    repository = Repository.find_by(id: repository_id)
    return unless repository

    Rails.logger.info "[SyncRepoMetadataJob] Syncing metadata for #{repository.url}"

    user = repository.users.joins(:project_repo_mappings).where.not(github_access_token: [ nil, "" ]).first
    unless user
      Rails.logger.warn "[SyncRepoMetadataJob] No user with GitHub token available for #{repository.url}"
      return
    end

    metadata = RepoHost::ServiceFactory.for_url(user, repository.url).fetch_repo_metadata
    if metadata
      repository.update!(metadata)
      Rails.logger.info "[SyncRepoMetadataJob] Updated metadata for #{repository.url}"
    else
      Rails.logger.warn "[SyncRepoMetadataJob] No metadata returned for #{repository.url}"
    end
  rescue ArgumentError => e
    raise unless e.message.include?("Unsupported repository host")
    Rails.logger.debug "[SyncRepoMetadataJob] Skipping unsupported host: #{repository&.url}"
  rescue RepoHost::RateLimitError
    raise
  rescue => e
    report_error(e, message: "[SyncRepoMetadataJob] Unexpected error")
    raise
  end
end
