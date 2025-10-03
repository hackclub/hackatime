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
              project: heartbeat.project,
              language: heartbeat.language,
              editor: heartbeat.editor,
              operating_system: heartbeat.operating_system,
              machine: heartbeat.machine,
              file: heartbeat.file,
              duration: heartbeat.duration
            }
          else
            render json: { heartbeat: nil }
          end
        end
      end
    end
  end
end
