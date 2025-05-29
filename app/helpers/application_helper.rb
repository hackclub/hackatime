module ApplicationHelper
  def cache_stats
    hits = Thread.current[:cache_hits] || 0
    misses = Thread.current[:cache_misses] || 0
    { hits: hits, misses: misses }
  end

  def admin_tool(class_name = "", element = "div", **options, &block)
    return unless current_user&.is_admin?
    concat content_tag(element, class: "admin-tool #{class_name}", **options, &block)
  end

  def dev_tool(class_name = "", element = "div", **options, &block)
    return unless Rails.env.development?
    concat content_tag(element, class: "dev-tool #{class_name}", **options, &block)
  end

  def country_to_emoji(country_code)
    # Hack to turn country code into the country's flag
    # https://stackoverflow.com/a/50859942
    country_code.tr("A-Z", "\u{1F1E6}-\u{1F1FF}")
  end

  # infer country from timezone
  def timezone_to_country(timezone)
    return null unless timezone.present?
    tz = ActiveSupport::TimeZone[timezone]
    return null unless tz && tz.tzinfo.respond_to?(:country_code)
    tz.tzinfo.country_code || null
  end

  def timezone_difference_in_seconds(timezone1, timezone2)
    return 0 if timezone1 == timezone2

    tz1 = ActiveSupport::TimeZone[timezone1]
    tz2 = ActiveSupport::TimeZone[timezone2]

    tz1.utc_offset - tz2.utc_offset
  end

  def timezone_difference_in_words(timezone1, timezone2)
    diff = timezone_difference_in_seconds(timezone1, timezone2)
    msg = distance_of_time_in_words(0, diff)

    if diff.zero?
      "same timezone"
    elsif diff.positive?
      "It's currently #{Time.zone.now.in_time_zone(timezone1).strftime("%H:%M")} in #{timezone1} (#{msg} ahead of you)"
    else
      "It's currently #{Time.zone.now.in_time_zone(timezone1).strftime("%H:%M")} in #{timezone1} (#{msg} behind of you)"
    end
  end

  def visualize_git_url(url)
    url.gsub("https://github.com/", "https://tkww0gcc0gkwwo4gc8kgs0sw.a.selfhosted.hackclub.com/")
  end

  def digital_time(time)
    hours = time.to_i / 3600
    minutes = (time.to_i % 3600) / 60
    seconds = time.to_i % 60

    [ hours, minutes, seconds ].map { |part| part.to_s.rjust(2, "0") }.join(":")
  end

  def short_time_simple(time)
    hours = time.to_i / 3600
    minutes = (time.to_i % 3600) / 60

    return "0m" if hours.zero? && minutes.zero?

    time_parts = []
    time_parts << "#{hours}h" if hours.positive?
    time_parts << "#{minutes}m" if minutes.positive?
    time_parts.join(" ")
  end

  def short_time_detailed(time)
    # ie. 5h 10m 10s
    # ie. 10m 10s
    # ie. 10m
    hours = time.to_i / 3600
    minutes = (time.to_i % 3600) / 60
    seconds = time.to_i % 60

    time_parts = []
    time_parts << "#{hours}h" if hours.positive?
    time_parts << "#{minutes}m" if minutes.positive?
    time_parts << "#{seconds}s" if seconds.positive?
    time_parts.join(" ")
  end

  def time_in_emoji(duration)
    # ie. 15.hours => "🕒"
    half_hours = duration.to_i / 1800
    clocks = [
        "🕛", "🕧",
        "🕐", "🕜",
        "🕑", "🕝",
        "🕒", "🕞",
        "🕓", "🕟",
        "🕔", "🕠",
        "🕕", "🕡",
        "🕖", "🕢",
        "🕗", "🕣",
        "🕘", "🕤",
        "🕙", "🕥",
        "🕚", "🕦"
    ]
    clocks[half_hours % clocks.length]
  end

  def human_interval_name(key, from: nil, to: nil)
    if key.present? && Heartbeat.respond_to?(:humanize_range) && Heartbeat::RANGES.key?(key.to_sym)
      Heartbeat.humanize_range(Heartbeat::RANGES[key.to_sym][:calculate].call)
    elsif from.present? && to.present?
      "#{from} to #{to}"
    else
      "All Time"
    end
  end
end
