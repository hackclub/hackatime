module My
  class ActivityDigestSubscriptionsController < ApplicationController
    before_action :ensure_current_user

    def show
      @channel_id = current_user.slack_neighborhood_channel
      @subscription = find_subscription
      @timezones = SlackActivityDigestSubscription::TIMEZONE_NAMES
    end

    def create
      channel_id = current_user.slack_neighborhood_channel
      if channel_id.blank?
        redirect_to my_activity_digest_subscription_path, alert: "We don't have a Slack team channel on file for you yet." and return
      end

      subscription = SlackActivityDigestSubscription.find_or_initialize_by(slack_channel_id: channel_id)
      subscription.assign_attributes(create_params)
      subscription.timezone ||= current_user.timezone
      subscription.delivery_hour ||= 10
      subscription.enabled = true
      subscription.created_by_user ||= current_user
      subscription.save!

      redirect_to my_activity_digest_subscription_path, notice: "Daily Slack digest enabled for #{subscription.channel_mention}."
    end

    def update
      subscription = find_subscription
      unless subscription
        redirect_to my_activity_digest_subscription_path, alert: "Digest is not enabled yet." and return
      end

      subscription.update!(update_params)
      redirect_to my_activity_digest_subscription_path, notice: "Digest preferences updated."
    end

    def destroy
      subscription = find_subscription
      if subscription
        subscription.update!(enabled: false)
      end

      redirect_to my_activity_digest_subscription_path, notice: "Daily Slack digest disabled."
    end

    private

    def find_subscription
      channel_id = current_user.slack_neighborhood_channel
      return nil if channel_id.blank?

      SlackActivityDigestSubscription.find_by(slack_channel_id: channel_id)
    end

    def create_params
      params.fetch(:slack_activity_digest_subscription, {}).permit(:timezone, :delivery_hour, :slack_team_id)
    end

    def update_params
      params.require(:slack_activity_digest_subscription).permit(:timezone, :delivery_hour)
    end

    def ensure_current_user
      redirect_to root_path, alert: "You must be logged in to manage the digest." unless current_user
    end
  end
end
