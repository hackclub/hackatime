module TimezoneRegions
  extend ActiveSupport::Concern

  OFFSET_NAMES = {
    -8 => "PST (UTC-8)", -7 => "MST (UTC-7)", -6 => "CST (UTC-6)",
    -5 => "EST (UTC-5)", -4 => "AST (UTC-4)", 0 => "GMT (UTC+0)",
    1 => "CET (UTC+1)", 2 => "EET (UTC+2)", 8 => "CST Asia (UTC+8)",
    9 => "JST (UTC+9)", 10 => "AEST (UTC+10)"
  }.freeze

  class_methods do
    def timezone_to_utc_offset(timezone)
      return nil if timezone.blank?
      tz = Time.find_zone(timezone)
      tz ? tz.now.utc_offset / 3600 : nil
    rescue TZInfo::InvalidTimezoneIdentifier, ArgumentError
      nil
    end

    def users_in_timezone_offset(utc_offset)
      matching = User.where.not(timezone: nil).distinct.pluck(:timezone)
                     .select { |tz| timezone_to_utc_offset(tz) == utc_offset }
      User.where(timezone: matching)
    end

    def users_in_timezone(timezone) = User.where(timezone: timezone)

    def available_timezone_offsets
      User.where.not(timezone: nil).distinct.pluck(:timezone)
          .map { |tz| timezone_to_utc_offset(tz) }.compact.uniq.sort
    end

    def available_timezones
      User.where.not(timezone: nil).distinct.pluck(:timezone).sort
    end

    def offset_to_name(utc_offset)
      OFFSET_NAMES[utc_offset] || "UTC#{utc_offset >= 0 ? '+' : ''}#{utc_offset}"
    end
  end

  included do
    def timezone_utc_offset = self.class.timezone_to_utc_offset(timezone)
    def timezone_offset_name
      offset = timezone_utc_offset
      offset ? self.class.offset_to_name(offset) : "Unknown"
    end
  end
end
