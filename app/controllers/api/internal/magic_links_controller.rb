module Api
  module Internal
    class MagicLinksController < ApplicationController
      def create
        slack_uid = params[:id]
        email = params[:email]

        unless slack_uid.present?
          return render json: {
            error: "gotta provide an ID, buddy..."
          }, status: 400
        end

        unless email.present?
          return render json: {
            error: "weird things happen without an email...,,"
          }, status: 400
        end

        begin
          user = User.find_or_create_by!(slack_uid: slack_uid)
          existing = user.persisted?

          # fucky merge logic, if we see the email already present, we merge it
          email_record = EmailAddress.find_by(email: email)
          if email_record && email_record.user_id != user.id
            email_record.update!(user_id: user.id)
          elsif !user.email_addresses.exists?(email: email)
            user.email_addresses.create!(email: email)
          end

          sign_in_token = user.sign_in_tokens.create!(
            magic_link_params.merge(
              auth_type: :program_magic_link,
              expires_at: Time.now + 5.minutes
            )
          )

          render json: {
            magic_link: auth_token_url(sign_in_token.token),
            existing:
          }
        rescue => e
          Sentry.capture_exception(e, extra: { slack_uid: slack_uid, email: email, params: params.to_unsafe_h })
          render json: { error: "internal error creating magic link" }, status: 500
        end
      end

      def magic_link_params
        params.permit(:continue_param, return_data: {})
      end
    end
  end
end
