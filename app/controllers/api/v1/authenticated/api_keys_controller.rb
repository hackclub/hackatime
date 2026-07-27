module Api
  module V1
    module Authenticated
      class ApiKeysController < ApplicationController
        def index
          render json: { token: api_key.token }
        end

        private

        def api_key
          @api_key ||= current_user.api_keys.first || current_user.api_keys.create!
        end

        def required_doorkeeper_scopes
          [ :api_key ]
        end
      end
    end
  end
end
