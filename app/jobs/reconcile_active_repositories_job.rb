# Keeps repository metadata and commits fresh for projects people are coding
# on now. Each run syncs at most BATCH_SIZE repositories whose mapped project
# had heartbeats within ACTIVE_WINDOW, oldest sync first, spread out over the
# hour. It only runs while the github_sync flag is enabled.
class ReconcileActiveRepositoriesJob < ApplicationJob
  include GithubApiJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :literally_whenever

  good_job_control_concurrency_with(total_limit: 1, key: -> { self.class.name })

  ACTIVE_WINDOW = 1.day
  STALE_AFTER = 6.hours
  BATCH_SIZE = 100
  SPACING = 15.seconds

  def perform
    mappings = active_mappings
    repositories = Repository.where(id: mappings.select(:repository_id))
      .where("last_synced_at IS NULL OR last_synced_at < ?", STALE_AFTER.ago)
      .order(Arel.sql("last_synced_at ASC NULLS FIRST"))
      .limit(BATCH_SIZE)
      .to_a
    user_ids_by_repository = mappings.where(repository_id: repositories.map(&:id))
      .distinct.pluck(:repository_id, :user_id)
      .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

    repositories.each_with_index do |repository, index|
      wait = index * SPACING
      SyncRepoMetadataJob.set(wait:).perform_later(repository.id)
      user_ids_by_repository.fetch(repository.id, []).each do |user_id|
        PullRepoCommitsJob.set(wait:).perform_later(user_id, repository.owner, repository.name)
      end
    end

    Rails.logger.info "[ReconcileActiveRepositoriesJob] Queued sync for #{repositories.size} repositories"
  end

  private

  def active_mappings
    recent_heartbeats = Heartbeat.with_excluded
      .where("heartbeats.user_id = project_repo_mappings.user_id AND heartbeats.project = project_repo_mappings.project_name")
      .where("heartbeats.time > ?", ACTIVE_WINDOW.ago.to_f)

    ProjectRepoMapping.active.where.not(repository_id: nil).where(recent_heartbeats.arel.exists)
  end
end
