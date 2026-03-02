module Api
  module Internal
    class RevocationsNormalController < Api::Internal::ApplicationController
      def create
        token = params[:token]

        return head 400 unless token.present?

        masked_token = mask_token(token)

        api_key = ApiKey.find_by(token:)

        unless api_key.present?
          return render json: { success: false }
        end

        api_key.update!(
          token: SecureRandom.uuid_v4,
          name: "#{api_key.name}_revoked_#{SecureRandom.hex(8)}"
        )

        user = api_key.user

        new_token_mask = mask_token(api_key.token)

        render json: {
          success: true,
          owner_email: user.email_addresses.first&.email,
          key_name: api_key.name
        }.compact_blank
      end

      private

      def mask_token(token)
        return nil unless token
        t = token.to_s
        return t if t.length <= 8
        "#{t[0,4]}...#{t[-4,4]}"
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
