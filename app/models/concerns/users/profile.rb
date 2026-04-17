module Users
  module Profile
    extend ActiveSupport::Concern

    def country_name
      ISO3166::Country.new(country_code).common_name
    end

    def country_subregion
      ISO3166::Country.new(country_code).subregion
    end

    def streak_days_formatted
      if streak_days > 30
        "30+"
      elsif streak_days < 1
        nil
      else
        streak_days.to_s
      end
    end

    def format_extension_text(duration)
      case hackatime_extension_text_type
      when "simple_text"
        return "Start coding to track your time" if duration.zero?
        ::ApplicationController.helpers.short_time_simple(duration)
      when "clock_emoji"
        ::ApplicationController.helpers.time_in_emoji(duration)
      when "compliment_text"
        FlavorText.compliment.sample
      end
    end

    def parse_and_set_timezone(timezone)
      as_tz = ActiveSupport::TimeZone[timezone]

      unless as_tz
        begin
          tzinfo = TZInfo::Timezone.get(timezone)
          as_tz = ActiveSupport::TimeZone.all.find do |z|
            z.tzinfo.identifier == tzinfo.identifier
          end
        rescue TZInfo::InvalidTimezoneIdentifier
        end
      end

      if as_tz
        self.timezone = as_tz.name
      else
        report_message("Invalid timezone #{timezone} for user #{id}")
      end
    end

    def avatar_url
      return slack_avatar_url if slack_avatar_url.present?
      return github_avatar_url if github_avatar_url.present?

      email = email_addresses&.first&.email
      if email.present?
        initials = email[0..1]&.upcase
        hashed_initials = Digest::SHA256.hexdigest(initials)[0..5]
        return "https://i2.wp.com/ui-avatars.com/api/#{initials}/48/#{hashed_initials}/fff?ssl=1"
      end

      base64_identicon = RubyIdenticon.create_base64(id.to_s)
      "data:image/png;base64,#{base64_identicon}"
    end

    def display_name
      name = slack_username || github_username || username
      return name if name.present?

      email = email_addresses&.first&.email
      return "error displaying name" unless email.present?

      email.split("@")&.first.truncate(10) + " (email sign-up)"
    end
  end
end
