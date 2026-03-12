module Api
  module Internal
    class RevocationsController < Api::Internal::ApplicationController
      REGULAR_KEY_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
      ADMIN_KEY_REGEX = /\Ahka_[0-9a-f]{64}\z/

      def create
        token = params[:token]

        return head 400 unless token.present?

        key, user = find_revocable_key_and_owner(token)

        return render json: { success: false } unless key.present?
        return render json: { success: false } unless revoke_key!(key)

        render json: {
          success: true,
          owner_email: user.email_addresses.first&.email,
          key_name: key.name
        }.compact_blank
      end

      private

      def find_revocable_key_and_owner(token)
        if token.match?(ADMIN_KEY_REGEX)
          key = AdminApiKey.active.find_by(token:)
          return [ key, key&.user ]
        end

        if token.match?(REGULAR_KEY_REGEX)
          # TODO: ApiKey currently has no active/revoked scope.
          # If one is added, prefer ApiKey.active here for consistency.
          key = ApiKey.find_by(token:)
          return [ key, key&.user ]
        end

        [ nil, nil ]
      end

      def revoke_key!(key)
        if key.is_a?(AdminApiKey)
          key.revoke!
        else
          key.user.rotate_api_key!
        end
      rescue ActiveRecord::ActiveRecordError => e
        Rails.logger.error("Revocation failed for #{key.class}##{key.id}: #{e.class} #{e.message}")
        false
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
