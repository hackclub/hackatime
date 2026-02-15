module Api
  module V1
    module Authenticated
      class ProjectsController < ApplicationController
        def index
          projects = project_stats_query.project_details.map do |project|
            {
              name: project[:name],
              total_seconds: project[:total_seconds],
              most_recent_heartbeat: project[:most_recent_heartbeat],
              languages: project[:languages],
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
