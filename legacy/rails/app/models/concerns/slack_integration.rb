module SlackIntegration
  extend ActiveSupport::Concern

  STATUS_EMOJI_BUCKETS = [
    [ 30.minutes,  %w[thinking cat-on-the-laptop loading-tumbleweed rac-yap] ],
    [ 1.hour,      %w[working-parrot meow_code] ],
    [ 2.hours,     %w[working-parrot meow-code] ],
    [ 3.hours,     %w[working-parrot cat-typing bangbang] ],
    [ 5.hours,     %w[cat-typing meow-code laptop-fire bangbang] ],
    [ 8.hours,     %w[cat-typing laptop-fire hole-mantelpiece_clock keyboard-fire bangbang bangbang] ],
    [ 15.hours,    %w[laptop-fire bangbang bangbang rac_freaking rac_freaking hole-mantelpiece_clock] ],
    [ 20.hours,    %w[bangbang bangbang rac_freaking hole-mantelpiece_clock] ]
  ].freeze
  STATUS_EMOJI_OVERFLOW = %w[areyousure time-to-stop].freeze

  def raw_slack_user_info
    return nil unless slack_uid.present?
    return nil unless slack_access_token.present?

    @slack_user_info ||= HTTP.auth("Bearer #{slack_access_token}")
      .get("https://slack.com/api/users.info?user=#{slack_uid}")

    JSON.parse(@slack_user_info.body.to_s).dig("user")
  end

  def update_from_slack
    user_data = raw_slack_user_info
    return unless user_data.present?

    apply_slack_profile_attributes(user_data)
    self.slack_synced_at = Time.current
  end

  # Assigns slack_username and slack_avatar_url from a Slack `user` payload.
  # Shared by SlackIntegration#update_from_slack and OauthAuthentication.from_slack_token.
  def apply_slack_profile_attributes(slack_user)
    profile = slack_user["profile"] || {}
    self.slack_avatar_url = profile["image_192"] || profile["image_72"]
    self.slack_username =
      profile["display_name_normalized"].presence ||
      profile["real_name_normalized"].presence ||
      slack_user["name"].presence
  end

  def update_slack_status
    return unless uses_slack_status?

    current_status_response = HTTP.auth("Bearer #{slack_access_token}")
      .get("https://slack.com/api/users.profile.get")

    current_status = JSON.parse(current_status_response.body.to_s)

    custom_status_regex = /spent on \w+ today$/
    status_present = current_status.dig("profile", "status_text").present?
    status_custom = !current_status.dig("profile", "status_text")&.match?(custom_status_regex)

    return if status_present && status_custom

    current_project = heartbeats.order(time: :desc).first&.project
    current_project_duration = Time.use_zone(timezone) do
      heartbeats.where(project: current_project)
                .today
                .duration_seconds
    end
    current_project_duration_formatted = ApplicationController.helpers.short_time_simple(current_project_duration)

    return if current_project_duration.zero?

    bucket = STATUS_EMOJI_BUCKETS.find { |threshold, _| current_project_duration < threshold }
    status_emoji = (bucket ? bucket.last : STATUS_EMOJI_OVERFLOW).sample

    status_emoji = ":#{status_emoji}:"
    status_text = "#{current_project_duration_formatted} spent on #{current_project} today"

    HTTP.auth("Bearer #{slack_access_token}")
      .post("https://slack.com/api/users.profile.set", form: {
        profile: {
          status_text:,
          status_emoji:,
          status_expiration: (Time.now + 10.minutes).to_i
        }
      })
  end
end
