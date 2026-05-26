class Api::V1::UsersController < ApplicationController
  before_action -> { authenticate_legacy_stats_api_key!(allow_query_param: false) }, unless: -> { Rails.env.development? }

  def lookup_email
    user = EmailAddress.find_by(email: params[:email])&.user
    if user.present?
      render json: { user_id: user.id, email: params[:email] }
    else
      render json: { error: "User not found", email: params[:email] }, status: :not_found
    end
  end

  def lookup_slack_uid
    user = User.find_by(slack_uid: params[:slack_uid])
    if user.present?
      render json: { user_id: user.id, slack_uid: params[:slack_uid] }
    else
      render json: { error: "User not found", slack_uid: params[:slack_uid] }, status: :not_found
    end
  end
end
