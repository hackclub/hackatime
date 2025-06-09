class ScanGithubReposJob < ApplicationJob
  queue_as :latency_5m

  include GoodJob::ActiveJobExtensions::Concurrency

  # Only allow one instance of this job to run at a time
  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "scan_github_repos_job_#{arguments.first.presence || 'all'}" },
    drop: true
  )

  def perform(user_id = nil)
    scope = User.where.not(github_uid: nil)
    scope = scope.where(id: user_id) if user_id.present?

    puts "Scanning GitHub repos for #{scope.count} users"
    scope.find_each(batch_size: 100) do |user|
      Rails.logger.info "Scanning GitHub repos for user #{user.id} (#{user.github_username})"

      # existing mappings
      existing_mappings = user.project_repo_mappings.pluck(:project_name)

      # Get unique project names from user's heartbeats
      project_names = user.heartbeats.where.not(project: existing_mappings)
                                     .distinct.pluck(:project).compact

      project_names.each do |project_name|
        # only queue the job once per hour
        Rails.cache.fetch("attempt_project_repo_mapping_job_#{user.id}_#{project_name}", expires_in: 1.hour) do
          AttemptProjectRepoMappingJob.perform_later(user.id, project_name)
        end
      end
    end
  end
end
