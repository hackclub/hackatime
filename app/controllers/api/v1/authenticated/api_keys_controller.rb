module Api
  module V1
    module Authenticated
      class ApiKeysController < ApplicationController
        def index
          render json: { token: api_key.token }
        end

        private

        def api_key
          @api_key ||= current_user.hackatime_api_key(create_if_missing: true)
        end
      end
    end
  end
end
