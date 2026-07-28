# frozen_string_literal: true

class CurrentlyHacking
  def self.count
    Cache::CurrentlyHackingCountJob.perform_now[:count]
  end

  def self.active_users
    data = Cache::CurrentlyHackingJob.perform_now
    data[:users].map do |user|
      project = data[:active_projects][user.id]
      {
        id: user.id,
        display_name: user.display_name,
        slack_uid: user.slack_uid,
        avatar_url: user.avatar_url,
        active_project: project && { name: project.project_name, repo_url: project.repo_url }
      }
    end
  end
end
