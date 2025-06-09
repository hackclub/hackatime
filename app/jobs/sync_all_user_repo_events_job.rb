class SyncAllUserRepoEventsJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  enqueue_limit

  def perform
    Rails.logger.info "Kicking off SyncAllUserRepoEventsJob"

    # Identify users:
    # 1. Authenticated with GitHub (have an access token and username)
    # 2. Have had heartbeats in the last 6 hours
    users_to_sync = User.where.not(github_access_token: nil)
                        .where.not(github_username: nil)
                        .joins(:heartbeats) # Assumes User has_many :heartbeats
                        .where("heartbeats.created_at >= ?", 6.hours.ago)
                        .distinct

    if users_to_sync.empty?
      Rails.logger.info "No users eligible for GitHub event sync at this time."
      return
    end

    Rails.logger.info "Found #{users_to_sync.count} users eligible for GitHub event sync."

    GoodJob::Batch.enqueue(description: "Sync GitHub events for #{users_to_sync.count} active users at #{Time.current.iso8601}") do
      users_to_sync.each do |user|
        # Enqueue a job for each user, specifying 'github' as the provider
        RepoHost::SyncUserEventsJob.perform_later(user_id: user.id, provider: :github)
      end
    end
    Rails.logger.info "Successfully enqueued batch for GitHub event sync."
  end
end
