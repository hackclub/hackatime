class SailorsLogLeaderboard < ApplicationRecord
  include ApplicationHelper  # for short_time_simple

  LANGUAGE_EMOJIS = {
    "ruby" => [ ":ruby:", ":-ruby:" ],
    "javascript" => [ ":js:" ],
    "js" => [ ":js:" ],
    "reactjs" => [ ":react:" ],
    "react" => [ ":react:" ],
    "typescript" => [ ":typescript:" ],
    "ts" => [ ":typescript:" ],
    "html" => [ ":html:" ],
    "java" => [ ":java:", ":java_duke:" ],
    "unity" => [ ":unity:", ":unity_new:" ],
    "c++" => [ ":c++:" ],
    "c" => [ ":c:", ":c_1:" ],
    "c#" => [ ":eyeglasses:" ],
    "onshape" => [ ":onshape:" ],
    "rust" => [ ":ferris:", ":crab:", ":ferrisowo:" ],
    "python" => [ ":snake:", ":python:", ":pf:", ":tw_snake:" ],
    "swift" => [ ":swift:" ],
    "xcode" => [ ":swift:" ],
    "x code" => [ ":swift:" ],
    "swiftui" => [ ":swift:" ],
    "swift ui" => [ ":swift:" ],
    "nix" => [ ":nix:", ":parrot-nix:" ],
    "nixos" => [ ":nix:" ],
    "nixpkgs" => [ ":nix:" ],
    "go" => [ ":golang:", ":gopher:", ":gothonk:" ],
    "golang" => [ ":golang:", ":gopher:", ":gothonk:" ],
    "deno" => [ ":deno:" ],
    "kotlin" => [ ":kotlin:" ],
    "astro" => [ ":astro:" ],
    "svelte" => [ ":svelte:" ]
  }.freeze

  validates :slack_channel_id, :slack_uid, presence: true
  after_create :generate_message

  def self.language_emoji(language)
    return nil if language.blank?
    LANGUAGE_EMOJIS[language.downcase]&.sample
  end

  def self.generate_leaderboard_stats(channel)
    slack_ids_in_channel = SailorsLogNotificationPreference.where(enabled: true, slack_channel_id: channel)
                                                           .distinct.pluck(:slack_uid)
    users_in_channel = User.where(slack_uid: slack_ids_in_channel)
    user_durations = Heartbeat.where(user: users_in_channel).today.group(:user_id).duration_seconds
    top_user_ids = user_durations.sort_by { |_, duration| -duration }.first(10).map(&:first)
    users_by_id = User.where(id: top_user_ids).index_by(&:id)

    top_user_ids.map do |user_id|
      user_heartbeats = Heartbeat.where(user_id: user_id).today
      most_common_languages = user_heartbeats.where.not(language: nil).group(:project, :language).count
        .group_by { |k, _| k[0] }
        .transform_values { |langs| langs.max_by { |_, count| count }&.first&.last }

      projects = user_heartbeats.group(:project).duration_seconds.map do |project, duration|
        {
          name: project, duration: duration,
          language: most_common_languages[project],
          language_emoji: language_emoji(most_common_languages[project])
        }
      end
      projects = projects.filter { |p| p[:duration] > 1.minute }.sort_by { |p| -p[:duration] }

      user = users_by_id.fetch(user_id) { raise ActiveRecord::RecordNotFound, "Couldn't find User with 'id'=#{user_id}" }
      {
        slack_uid: user.slack_uid,
        name: SlackUsername.find_by_uid(user.slack_uid),
        duration: user_durations[user_id],
        projects: projects
      }
    end
  end

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
        parts = [ project[:name] ]
        parts << "[#{language}]" unless language.nil?
        parts << short_time_simple(project[:duration])
        parts.join(" ")
      end.join(" + ")
    end
    msg = "No coding activity found for today. :3kskull:" if stats.empty?
    update_column(:message, msg)
  end
end
