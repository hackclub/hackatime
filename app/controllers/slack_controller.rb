class SlackController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_slack_request

  # allow usage of short_time_simple
  include ApplicationHelper
  helper_method :short_time_simple

  # Handle slack commands
  def create
    if params_hash[:command].to_s.downcase.include?("sailorslog")
      user = User.find_by(slack_uid: params_hash[:user_id])
      unless user
        render json: {
          response_type: "ephemeral",
          text: "Darn it! I could not find a hackatime account linked with your slack account! please sign up and link your slack account at https://hackatime.hackclub.com/my/settings"
        }
        return
      end
    end

    SlackCommand::SailorsLogJob.perform_later(params_hash)
  end

  private

  def params_hash
    @params_hash ||= params.permit(:command, :text, :response_url, :user_id, :team_id, :team_domain,
                                   :channel_id, :channel_name, :user_name, :trigger_word).to_h
  end

  def verify_slack_request
    return true if Rails.env.development?

    timestamp = request.headers["X-Slack-Request-Timestamp"]
    received_signature = request.headers["X-Slack-Signature"]

    if timestamp.blank? || (Time.now.to_i - timestamp.to_i).abs > 300
      return head(:unauthorized)
    end

    sig_basestring = "v0:#{timestamp}:#{request.raw_post}"
    computed_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", ENV["SAILORS_LOG_SLACK_SIGNING_SECRET"], sig_basestring)

    head(:unauthorized) unless ActiveSupport::SecurityUtils.secure_compare(received_signature, computed_signature)
  end
end
