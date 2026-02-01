module Api
  module Internal
    class RevocationsController < Api::Internal::ApplicationController
      def create
        token = params[:token]

        return head 400 unless token.present?

        admin_api_key = AdminApiKey.active.find_by(token:)

        return render json: { success: false } unless admin_api_key.present?

        admin_api_key.revoke!

        user = admin_api_key.user

        render json: {
          success: true,
          owner_email: user.email_addresses.first&.email,
          key_name: admin_api_key.name
        }.compact_blank
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
