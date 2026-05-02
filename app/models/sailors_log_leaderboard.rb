class SailorsLogLeaderboard < ApplicationRecord
  include ApplicationHelper  # Add this to get access to short_time_simple
  validates :slack_channel_id, :slack_uid, presence: true
  after_create :generate_message

  private

  def generate_message
    stats = SailorsLogLeaderboard.generate_leaderboard_stats(slack_channel_id)
    msg = "*:boat: Sailor's Log - Today*"
    medals = [ "first_place_medal", "second_place_medal", "third_place_medal" ]

    stats.each_with_index do |entry, index|
      medal = medals[index] || "white_small_square"
      msg += "\n:#{medal}: `@#{entry[:name]}`: #{short_time_simple entry[:duration]} → "
      msg += entry[:projects].map do |project|
        language = project[:language_emoji] ? "#{project[:language_emoji]} #{project[:language]}" : project[:language]

        project_entry = []
        project_entry << "#{project[:name]}"
        project_entry << "[#{language}]" unless language.nil?
        project_entry << "#{short_time_simple project[:duration]}"
        project_entry.join(" ")
      end.join(" + ")
    end

    msg = "No coding activity found for today. :3kskull:" if stats.empty?

    # Update the message attribute and save
    update_column(:message, msg)
  end

  def self.generate_leaderboard_stats(channel)
    # Get all users with enabled preferences in the channel
    slack_ids_in_channel = SailorsLogNotificationPreference.where(enabled: true, slack_channel_id: channel)
                                                           .distinct
                                                           .pluck(:slack_uid)

    users_in_channel = User.where(slack_uid: slack_ids_in_channel)

    # Get all durations for users in channel
    user_durations = Heartbeat.where(user: users_in_channel)
                              .today
                              .group(:user_id)
                              .duration_seconds

    # Sort and take top 10 users
    top_user_ids = user_durations.sort_by { |_, duration| -duration }.first(10).map(&:first)

    # Now get detailed project info only for top 10 users
    top_user_ids.map do |user_id|
      user_heartbeats = Heartbeat.where(user_id: user_id).today

      # Get most common language per project using ActiveRecord
      most_common_languages = user_heartbeats
        .where.not(language: nil)
        .group(:project, :language)
        .count
        .group_by { |k, _| k[0] }  # Group by project
        .transform_values { |langs| langs.max_by { |_, count| count }&.first&.last } # Get most common language

      # Get all project durations in one query
      project_durations = user_heartbeats
        .group(:project)
        .duration_seconds

      projects = project_durations.map do |project, duration|
        print "project: #{project}, duration: #{duration}, language: #{most_common_languages[project]}"
        {
          name: project,
          duration: duration,
          language: most_common_languages[project],
          language_emoji: self.language_emoji(most_common_languages[project])
        }
      end

      projects = projects.filter { |project| project[:duration] > 1.minute }.sort_by { |project| -project[:duration] }

      user = User.find user_id
      {
        slack_uid: user.slack_uid,
        name: SlackUsername.find_by_uid(user.slack_uid),
        duration: user_durations[user_id],
        projects: projects
      }
    end
  end

  def self.language_emoji(language)
    return nil if language.blank?

    language = language.downcase
    case language
    when "ruby"
      [ ":#{language}:" || ":-ruby:" ].sample
    when "javascript"
      ":js:"
    when "js"
      ":js:"
    when "reactjs", "react"
      ":react:"
    when "typescript"
      ":typescript:"
    when "ts"
      ":typescript:"
    when "html"
      ":#{language}:"
    when "java"
      [ ":java:", ":java_duke:" ].sample
    when "unity"
      [ ":unity:", ":unity_new:" ].sample
    when "c++"
      ":#{language}:"
    when "c"
      [ ":c:", ":c_1:" ].sample
    when "c#"
      ":eyeglasses:"
    when "onshape"
      ":#{language}:"
    when "rust"
      [ ":ferris:", ":crab:", ":ferrisowo:" ].sample
    when "python"
      [ ":snake:", ":python:", ":pf:", ":tw_snake:" ].sample
    when "swift", "xcode", "x code", "swiftui", "swift ui"
      ":swift:"
    when "nix"
      [ ":nix:", ":parrot-nix:" ].sample
    when "nixos", "nixpkgs"
      ":nix:"
    when "go", "golang"
      [ ":golang:", ":gopher:", ":gothonk:" ].sample
    when "deno"
      ":deno:"
    when "kotlin"
      ":#{language}:"
    when "astro"
      ":#{language}:"
    when "svelte"
      ":svelte:"
    else
      nil
    end
  end
end
