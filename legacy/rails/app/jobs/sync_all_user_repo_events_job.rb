class SyncAllUserRepoEventsJob < ApplicationJob
  queue_as :literally_whenever

  include HasEnqueueControl
  enqueue_limit

  def perform
    Rails.logger.info "Kicking off SyncAllUserRepoEventsJob"

    # Users with GitHub auth that had heartbeats in the last 6 hours
    users = User.where.not(github_access_token: nil).where.not(github_username: nil)
                .joins(:heartbeats).where("heartbeats.created_at >= ?", 6.hours.ago).distinct

    if users.empty?
      Rails.logger.info "No users eligible for GitHub event sync at this time."
      return
    end

    Rails.logger.info "Found #{users.count} users eligible for GitHub event sync."

    GoodJob::Batch.enqueue(description: "Sync GitHub events for #{users.count} active users at #{Time.current.iso8601}") do
      users.each { |u| RepoHost::SyncUserEventsJob.perform_later(user_id: u.id, provider: :github) }
    end
    Rails.logger.info "Successfully enqueued batch for GitHub event sync."
  end
end
