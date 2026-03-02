module Api
  module Internal
    class RevocationsController < Api::Internal::ApplicationController
      REGULAR_KEY_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
      ADMIN_KEY_REGEX = /\Ahka_[0-9a-f]{64}\z/

      def create
        token = params[:token]

        return head 400 unless token.present?

        key, user = revocable_key_and_owner(token)

        return render json: { success: false } unless key.present?

        revoke_key!(key)

        render json: {
          success: true,
          owner_email: user.email_addresses.first&.email,
          key_name: key.name
        }.compact_blank
      end

      private

      def revocable_key_and_owner(token)
        if token.match?(ADMIN_KEY_REGEX)
          key = AdminApiKey.active.find_by(token:)
          return [ key, key&.user ]
        end

        if token.match?(REGULAR_KEY_REGEX)
          key = ApiKey.find_by(token:)
          return [ key, key&.user ]
        end

        [ nil, nil ]
      end

      def revoke_key!(key)
        return key.revoke! if key.is_a?(AdminApiKey)

        key.update!(
          token: SecureRandom.uuid_v4,
          name: "#{key.name}_revoked_#{SecureRandom.hex(8)}"
        )
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
