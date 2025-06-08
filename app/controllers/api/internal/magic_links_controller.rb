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

        existing_user = true

        user = User.find_or_create_by!(slack_uid:) do |u|
          existing_user = false
          u.email_addresses.build(email:)
        end

        sign_in_token = user.sign_in_tokens.create!(
          magic_link_params.merge(
            auth_type: :program_magic_link,
            expires_at: Time.now + 5.minutes
          )
        )

        render json: {
          magic_link: auth_token_url(sign_in_token.token),
          existing_user:
        }
      end

      def magic_link_params
        params.permit(:continue_param)
      end
    end
  end
end