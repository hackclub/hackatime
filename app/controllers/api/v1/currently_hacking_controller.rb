class Api::V1::CurrentlyHackingController < ApplicationController
  def index
    data = Cache::CurrentlyHackingJob.perform_now

    users = data[:users].map do |user|
      proj = data[:active_projects][user.id]

      {
        display_name: user.display_name,
        avatar_url: user.avatar_url,
        country_code: user.country_code,
        working_on: proj && {
          project_name: proj.project_name,
          repo_url: proj.repo_url
        }
      }
    end

    render json: { count: users.size, users: users }
  end
end
