module Api
  module Internal
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate!

      private

      def authenticate!
        res = authenticate_with_http_token do |token, _|
          ENV["INTERNAL_API_KEYS"]&.split(', ')&.include?(token)
        end
        unless res
          redirect_to "https://www.youtube.com/watch?v=dQw4w9WgXcQ", allow_other_host: true
        end
      end
    end
  end
end
