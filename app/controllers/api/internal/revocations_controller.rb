module Api
  module Internal
    class RevocationsController < Api::Internal::ApplicationController
      REGULAR_KEY_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
      ADMIN_KEY_REGEX = /\Ahka_[0-9a-f]{64}\z/

      def create
        token = params[:token]

        return render_error("Token is required") unless token.present?

        case token
        when ADMIN_KEY_REGEX
          key = AdminApiKey.active.find_by(token:)
          token_type = "Hackatime Admin API Key"
        when REGULAR_KEY_REGEX
          key = ApiKey.find_by(token:)
          token_type = "Hackatime API Key"
        else
          return render_error("Token doesn't match any supported type")
        end

        user = key&.user
        original_key_name = key&.name

        return render_error("Token is invalid or already revoked") unless key.present?
        return render_error("Token is invalid or already revoked") unless revoke_key(key)

        render json: {
          success: true,
          status: "complete",
          token_type: token_type,
          owner_email: user.email_addresses.first&.email,
          key_name: original_key_name
        }.compact_blank, status: :created
      end

      private

      def revoke_key(key)
        if key.is_a?(AdminApiKey)
          key.revoke!
        else
          key.user.rotate_single_api_key!(key)
        end
      rescue ActiveRecord::ActiveRecordError => e
        Rails.logger.error("Revocation failed for #{key.class}##{key.id}: #{e.class} #{e.message}")
        false
      end

      def render_error(message)
        render json: { success: false, error: message }, status: :unprocessable_entity
      end

      private def authenticate!
        res = authenticate_with_http_token do |token, _|
          ActiveSupport::SecurityUtils.secure_compare(token, ENV["HKA_REVOCATION_KEY"])
        end
        unless res
          redirect_to "https://www.youtube.com/watch?v=dQw4w9WgXcQ", allow_other_host: true
        end
      end
    end
  end
end
