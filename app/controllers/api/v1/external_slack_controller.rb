module Api
  module V1
    class ExternalSlackController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :verify_stats_api_token

      def create_user
        token = params[:token]
        return render json: { error: "Token is required" }, status: :bad_request unless token.present?

        # First get user ID from auth.test
        auth_response = HTTP.auth("Bearer #{token}")
          .get("https://slack.com/api/auth.test")

        auth_data = JSON.parse(auth_response.body.to_s)
        return render json: { error: "Invalid Slack token" }, status: :unauthorized unless auth_data["ok"]

        user_id = auth_data["user_id"]
        return render json: { error: "User ID not found" }, status: :bad_request unless user_id.present?

        user = User.find_or_initialize_by(slack_uid: user_id)

        if user.persisted?
          return render json: {
            user_id: user.id,
            username: user.display_name,
            email: user.email_addresses.first&.email
          }, status: :ok
        end

        user.slack_access_token = token

        user_data = user.raw_slack_user_info
        return render json: { error: "Invalid Slack token" }, status: :unauthorized unless user_data.present?

        email = user_data.dig("profile", "email")
        return render json: { error: "Email not found" }, status: :bad_request unless email.present?

        email_address = EmailAddress.find_or_initialize_by(email: email)
        email_address.source ||= :slack
        user.email_addresses << email_address unless user.email_addresses.include?(email_address)

        user.update_from_slack
        user.parse_and_set_timezone(user_data["tz"])

        if user.save
          render json: {
            user_id: user.id,
            username: user.display_name,
            email: email
          }, status: :created
        else
          render json: { error: user.errors.full_messages }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Error creating user from external Slack data: #{e.message}"
        render json: { error: "Internal server error" }, status: :internal_server_error
      end

      private

      def verify_stats_api_token
        token = request.headers["Authorization"]&.split(" ")&.last
        render json: { error: "Invalid API token" }, status: :unauthorized unless token == ENV["STATS_API_KEY"]
      end
    end
  end
end
