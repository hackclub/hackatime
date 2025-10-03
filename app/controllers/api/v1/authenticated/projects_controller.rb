module Api
  module V1
    module Authenticated
      class ProjectsController < ApplicationController
        def index
          projects = current_user.heartbeats
            .where.not(project: [nil, ""])
            .group(:project)
            .map { |project| 
              {
                name: project,
                total_seconds: time_per_project[project] || 0,
                most_recent_heartbeat: most_recent_heartbeat_per_project[project] ? Time.at(most_recent_heartbeat_per_project[project]).strftime("%Y-%m-%dT%H:%M:%SZ") : nil,
                percentage: time_per_project.sum { |_, secs| secs }.zero? ? 0 : ((time_per_project[project] || 0) / time_per_project.sum { |_, secs| secs }.to_f * 100).round(2),
                repo: project_repo_mappings[project]&.repo,
              }
            }

          render json: { projects: projects }
        end

        private

        def project_repo_mappings
          @project_repo_mappings ||= current_user.project_repo_mappings
                                                 .index_by(&:project)
        end

        def time_per_project
          @time_per_project ||= current_user.heartbeats
                                            .with_valid_timestamps
                                            .where.not(project: [nil, ""])
                                            .group(:project)
                                            .duration_seconds
        end

        def most_recent_heartbeat_per_project
          @most_recent_heartbeat_per_project ||= current_user.heartbeats
                                                             .with_valid_timestamps
                                                             .where.not(project: [nil, ""])
                                                             .group(:project)
                                                             .maximum(:time)
        end
      end
    end
  end
end
