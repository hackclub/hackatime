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

  def events
    return render(json: { challenge: params[:challenge] }) if params[:type] == "url_verification"

    if params[:type] == "event_callback" && params.dig(:event, :type) == "user_change"
      slack_user = params.dig(:event, :user)
      user = User.find_by(slack_uid: slack_user[:id]) if slack_user
      SlackProfileSyncJob.perform_later(user.id) if user && slack_profile_changed?(user, slack_user)
    end

    head :ok
  end

  private

  def slack_profile_changed?(user, slack_user)
    profile = slack_user[:profile] || {}
    slack_username =
      profile[:display_name_normalized].presence ||
      profile[:real_name_normalized].presence ||
      slack_user[:name].presence
    slack_avatar_url = profile[:image_192].presence || profile[:image_72].presence
    slack_email = profile[:email].to_s.strip.downcase.presence

    (slack_username.present? && slack_username != user.slack_username) ||
      (slack_avatar_url.present? && slack_avatar_url != user.slack_avatar_url) ||
      (slack_email.present? && slack_email != user.email_addresses.source_slack.pick(:email))
  end

  def params_hash
    @params_hash ||= params.permit(:command, :text, :response_url, :user_id, :team_id, :team_domain,
                                   :channel_id, :channel_name, :user_name, :trigger_word).to_h
  end

  def verify_slack_request
    return true if Rails.env.development?

    signing_secret_name = action_name == "events" ? "SLACK_SIGNING_SECRET" : "SAILORS_LOG_SLACK_SIGNING_SECRET"
    signing_secret = ENV[signing_secret_name]
    if signing_secret.blank?
      # we will never hit this in prod but this is good prep for `config.saas_mode`
      Rails.logger.error "[SlackController] #{signing_secret_name} is not configured"
      return head(:unauthorized)
    end

    timestamp = request.headers["X-Slack-Request-Timestamp"]
    received_signature = request.headers["X-Slack-Signature"]

    if timestamp.blank? || received_signature.blank? || (Time.now.to_i - timestamp.to_i).abs > 300
      return head(:unauthorized)
    end

    sig_basestring = "v0:#{timestamp}:#{request.raw_post}"
    computed_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, sig_basestring)

    head(:unauthorized) unless ActiveSupport::SecurityUtils.secure_compare(received_signature, computed_signature)
  end
end
