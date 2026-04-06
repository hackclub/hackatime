class Api::V1::UsersController < ApplicationController
  before_action :ensure_authenticated!

  def lookup_email
    email = params[:email]

    user = EmailAddress.find_by_email(email)&.user

    if user.present?
      render json: { user_id: user.id, email: email }
    else
      render json: { error: "User not found", email: email }, status: :not_found
    end
  end

  def lookup_slack_uid
    slack_uid = params[:slack_uid]

    user = User.find_by(slack_uid: slack_uid)

    if user.present?
      render json: { user_id: user.id, slack_uid: slack_uid }
    else
      render json: { error: "User not found", slack_uid: slack_uid }, status: :not_found
    end
  end

  private

  def ensure_authenticated!
    return if Rails.env.development?

    token = request.headers["Authorization"]&.split(" ")&.last
    render json: { error: "Unauthorized" }, status: :unauthorized unless token == ENV["STATS_API_KEY"]
  end
end
