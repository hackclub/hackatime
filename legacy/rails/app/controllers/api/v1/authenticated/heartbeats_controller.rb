module Api
  module V1
    module Authenticated
      class HeartbeatsController < ApplicationController
        def latest
          heartbeat = current_user.heartbeats
                                  .where.not(source_type: :test_entry)
                                  .order(time: :desc)
                                  .first

          if heartbeat
            render json: {
              id: heartbeat.id,
              created_at: heartbeat.created_at,
              time: heartbeat.time,
              category: heartbeat.category,
              project: heartbeat.project,
              language: heartbeat.language,
              editor: heartbeat.editor,
              operating_system: heartbeat.operating_system,
              machine: heartbeat.machine,
              entity: heartbeat.entity
            }
          else
            render json: { heartbeat: nil }
          end
        end
      end
    end
  end
end
