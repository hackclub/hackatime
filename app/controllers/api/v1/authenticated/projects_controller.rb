module Api
  module V1
    module Authenticated
      class ProjectsController < ApplicationController
        require_oauth_scope :read

        def index
          projects = project_stats_query.project_details.map do |project|
            {
              name: project[:name],
              total_seconds: project[:total_seconds],
              languages: project[:languages],
              repo_url: project[:repo_url],
              first_heartbeat: project[:first_heartbeat],
              last_heartbeat: project[:last_heartbeat],
              most_recent_heartbeat: project[:most_recent_heartbeat],
              archived: project[:archived]
            }
          end

          render json: { projects: projects }
        end

        private

        def project_stats_query
          @project_stats_query ||= ProjectStatsQuery.new(
            user: current_user,
            params: params,
            include_archived: params[:include_archived] == "true",
            default_discovery_start: 0,
            default_stats_start: 0
          )
        end
      end
    end
  end
end
