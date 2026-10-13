class ScanGithubReposJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "scan_github_repos_job_#{arguments.first.presence || 'all'}" }
  )

  def perform(user_id = nil)
    scope = User.where.not(github_uid: nil)
    scope = scope.where(id: user_id) if user_id.present?

    puts "Scanning GitHub repos for #{scope.count} users"
    scope.find_each(batch_size: 100) do |user|
      Rails.logger.info "Scanning GitHub repos for user #{user.id} (#{user.github_username})"
      existing = user.project_repo_mappings.pluck(:project_name)
      project_names = user.heartbeats.where.not(project: existing).distinct.pluck(:project).compact

      project_names.each { |project_name| AttemptProjectRepoMappingJob.enqueue_for(user, project_name) }
    end
  end
end
