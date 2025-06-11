module TimezoneRegions
  extend ActiveSupport::Concern

  class_methods do
    def timezone_to_utc_offset(timezone)
      return nil if timezone.blank?

      begin
        tz = Time.find_zone(timezone)
        return nil unless tz
        tz.now.utc_offset / 3600 # Convert seconds to hours
      rescue
        nil
      end
    end

    def users_in_timezone_offset(utc_offset)
      # Get all users whose timezone has the same UTC offset
      user_timezones = User.where.not(timezone: nil).distinct.pluck(:timezone)
      matching_timezones = user_timezones.select do |tz|
        timezone_to_utc_offset(tz) == utc_offset
      end
      User.where(timezone: matching_timezones)
    end

    def users_in_timezone(timezone)
      User.where(timezone: timezone)
    end

    def available_timezone_offsets
      # Get all unique UTC offsets that have users
      user_timezones = User.where.not(timezone: nil).distinct.pluck(:timezone)
      offsets = user_timezones.map { |tz| timezone_to_utc_offset(tz) }.compact.uniq.sort
      offsets
    end

    def available_timezones
      # Only return timezones that have users
      User.where.not(timezone: nil).distinct.pluck(:timezone).sort
    end

    def offset_to_name(utc_offset)
      case utc_offset
      when -8 then "PST (UTC-8)"
      when -7 then "MST (UTC-7)"
      when -6 then "CST (UTC-6)"
      when -5 then "EST (UTC-5)"
      when -4 then "AST (UTC-4)"
      when 0 then "GMT (UTC+0)"
      when 1 then "CET (UTC+1)"
      when 2 then "EET (UTC+2)"
      when 8 then "CST Asia (UTC+8)"
      when 9 then "JST (UTC+9)"
      when 10 then "AEST (UTC+10)"
      else "UTC#{utc_offset >= 0 ? '+' : ''}#{utc_offset}"
      end
    end
  end

  included do
    def timezone_utc_offset
      self.class.timezone_to_utc_offset(timezone)
    end

    def timezone_offset_name
      offset = timezone_utc_offset
      return "Unknown" unless offset
      self.class.offset_to_name(offset)
    end
  end
end
