# frozen_string_literal: true

# Users sending heartbeats right now, refreshed by SiteActivityCacheJob.
class CurrentlyHacking
  WINDOW = 5.minutes

  def self.count(force: false)
    Rails.cache.fetch("currently_hacking/count", expires_in: Heartbeat::SITE_ACTIVITY_CACHE_TTL, force:) do
      User.where(id: recent_heartbeats.distinct.pluck(:user_id)).count
    end
  end

  # { users: [User], active_projects: { user_id => ProjectRepoMapping or nil } },
  # users with a mapped active project first.
  def self.data(force: false)
    Rails.cache.fetch("currently_hacking/data", expires_in: Heartbeat::SITE_ACTIVITY_CACHE_TTL, force:) do
      latest_projects = recent_heartbeats.group(:user_id).pluck(:user_id, Arel.sql("argMax(project, (time, id))")).to_h

      users = User.where(id: latest_projects.keys).includes(:project_repo_mappings, :email_addresses).to_a
      active_projects = users.to_h do |user|
        mapping = user.project_repo_mappings.find { |p| p.project_name == latest_projects[user.id] }
        [ user.id, mapping&.archived? ? nil : mapping ]
      end

      users = users.sort_by { |u| [ active_projects[u.id].present? ? 0 : 1, u.display_name.present? ? 0 : 1 ] }
      { users:, active_projects: }
    end
  end

  def self.active_users
    current = data
    current[:users].map do |user|
      project = current[:active_projects][user.id]
      {
        id: user.id,
        display_name: user.display_name,
        slack_uid: user.slack_uid,
        avatar_url: user.avatar_url,
        active_project: project && { name: project.project_name, repo_url: project.repo_url }
      }
    end
  end

  def self.recent_heartbeats
    Heartbeat.where(source_type: :direct_entry).coding_only.where("time > ?", WINDOW.ago.to_f)
  end
  private_class_method :recent_heartbeats
end
