module Api
  module Internal
    class ApplicationController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate!

      private

      def authenticate!
        authenticated = authenticate_with_http_token do |token, _|
          next false if token.blank?

          token_hash = ::Digest::SHA256.digest(token)
          expected_api_keys.any? do |expected|
            next false if expected.blank?

            ActiveSupport::SecurityUtils.secure_compare(token_hash, ::Digest::SHA256.digest(expected))
          end
        end

        head :unauthorized unless authenticated
      end

      def expected_api_keys
        ENV["INTERNAL_API_KEYS"].to_s.split(",")
      end
    end
  end
end
