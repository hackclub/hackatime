module Api
  module Internal
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate!

      private

      def authenticate!
        res = authenticate_with_http_token do |token, _|
          next false if token.blank?
          token_hash = ::Digest::SHA256.digest(token)
          ENV["INTERNAL_API_KEYS"]&.split(",")&.any? do |expected|
            next false if expected.blank?
            ActiveSupport::SecurityUtils.secure_compare(token_hash, ::Digest::SHA256.digest(expected))
          end
        end
        unless res
          redirect_to "https://www.youtube.com/watch?v=dQw4w9WgXcQ", allow_other_host: true
        end
      end
    end
  end
end
