module Api
  module V1
    module Authenticated
      class ProjectsController < ApplicationController
        def index
          projects = time_per_project.map { |project, _|
              {
                name: project,
                total_seconds: time_per_project[project] || 0,
                most_recent_heartbeat: most_recent_heartbeat_per_project[project] ? Time.at(most_recent_heartbeat_per_project[project]).strftime("%Y-%m-%dT%H:%M:%SZ") : nil,
                languages: languages_per_project[project] || []
              }
            }

          render json: { projects: projects }
        end

        private

        def time_per_project
          @time_per_project ||= current_user.heartbeats
                                            .with_valid_timestamps
                                            .where.not(project: [ nil, "" ])
                                            .group(:project)
                                            .duration_seconds
        end

        def most_recent_heartbeat_per_project
          @most_recent_heartbeat_per_project ||= current_user.heartbeats
                                                             .with_valid_timestamps
                                                             .where.not(project: [ nil, "" ])
                                                             .group(:project)
                                                             .maximum(:time)
        end

        def languages_per_project
          @languages_per_project ||= current_user.heartbeats
                                                 .with_valid_timestamps
                                                 .where.not(project: [ nil, "" ])
                                                 .where.not(language: [ nil, "" ])
                                                 .distinct
                                                 .pluck(:project, :language)
                                                 .group_by(&:first)
                                                 .transform_values { |pairs| pairs.map(&:last).uniq }
        end
      end
    end
  end
end
