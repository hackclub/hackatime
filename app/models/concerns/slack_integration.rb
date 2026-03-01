module SlackIntegration
  extend ActiveSupport::Concern

  def set_timezone_from_slack
    return unless slack_uid.present?

    user_response = HTTP.auth("Bearer #{slack_access_token}")
      .get("https://slack.com/api/users.info?user=#{slack_uid}")

    user_data = JSON.parse(user_response.body.to_s)

    return unless user_data["ok"]

    timezone_string = user_data.dig("user", "tz")

    return unless timezone_string.present?

    parse_and_set_timezone(timezone_string)
  end

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

    profile = user_data["profile"] || {}

    self.slack_avatar_url = profile["image_192"] || profile["image_72"]

    self.slack_username = profile["display_name_normalized"].presence
    self.slack_username ||= profile["real_name_normalized"].presence
    self.slack_username ||= user_data["name"].presence
    self.slack_synced_at = Time.current
  end

  def update_slack_status
    return unless uses_slack_status?
    return unless slack_access_token.present?

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

    status_emoji =
      case current_project_duration
      when 0...30.minutes
        %w[thinking cat-on-the-laptop loading-tumbleweed rac-yap]
      when 30.minutes...1.hour
        %w[working-parrot meow_code]
      when 1.hour...2.hours
        %w[working-parrot meow-code]
      when 2.hours...3.hours
        %w[working-parrot cat-typing bangbang]
      when 3.hours...5.hours
        %w[cat-typing meow-code laptop-fire bangbang]
      when 5.hours...8.hours
        %w[cat-typing laptop-fire hole-mantelpiece_clock keyboard-fire bangbang bangbang]
      when 8.hours...15.hours
        %w[laptop-fire bangbang bangbang rac_freaking rac_freaking hole-mantelpiece_clock]
      when 15.hours...20.hours
        %w[bangbang bangbang rac_freaking hole-mantelpiece_clock]
      else
        %w[areyousure time-to-stop]
      end.sample

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
