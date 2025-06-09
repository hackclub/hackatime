module TimeRangeFilterable
  extend ActiveSupport::Concern

  RANGES = {
    today: {
      human_name: "Today",
      calculate: -> { Time.current.beginning_of_day..Time.current.end_of_day }
    },
    yesterday: {
      human_name: "Yesterday",
      calculate: -> { (Time.current - 1.day).beginning_of_day..(Time.current - 1.day).end_of_day }
    },
    this_week: {
      human_name: "This Week",
      calculate: -> { Time.current.beginning_of_week..Time.current.end_of_week }
    },
    last_7_days: {
      human_name: "Last 7 Days",
      calculate: -> { (Time.current - 7.days).beginning_of_day..Time.current.end_of_day }
    },
    this_month: {
      human_name: "This Month",
      calculate: -> { Time.current.beginning_of_month..Time.current.end_of_month }
    },
    last_30_days: {
      human_name: "Last 30 Days",
      calculate: -> { (Time.current - 30.days).beginning_of_day..Time.current.end_of_day }
    },
    this_year: {
      human_name: "This Year",
      calculate: -> { Time.current.beginning_of_year..Time.current.end_of_year }
    },
    last_12_months: {
      human_name: "Last 12 Months",
      calculate: -> { (Time.current - 12.months).beginning_of_day..Time.current.end_of_day }
    },
    high_seas: {
      human_name: "High Seas",
      calculate: -> {
        timezone = "America/New_York"
        Time.use_zone(timezone) do
          from = Time.parse("2024-10-30").beginning_of_day
          to = Time.parse("2025-01-31").end_of_day
          from.beginning_of_day..to.end_of_day
        end
      }
    },
    low_skies: {
      human_name: "Low Skies",
      calculate: -> {
        timezone = "America/New_York"
        Time.use_zone(timezone) do
          from = Time.parse("2024-10-3").beginning_of_day
          to = Time.parse("2025-01-12").end_of_day
          from.beginning_of_day..to.end_of_day
        end
      }
    },
    scrapyard: {
      human_name: "Scrapyard Global",
      calculate: -> {
        timezone = "America/New_York"
        Time.use_zone(timezone) do
          from = Time.parse("2025-03-14").beginning_of_day
          to = Time.parse("2025-03-17").end_of_day
          from.beginning_of_day..to.end_of_day
        end
      }
    }
  }.freeze

  class_methods do
    def time_range_filterable_field(field_name)
      RANGES.each do |name, config|
        scope name, -> { where(field_name => config[:calculate].call) }
      end

      define_singleton_method(:humanize_range) do |range|
        RANGES.each do |name, config|
          return config[:human_name] if range == config[:calculate].call
        end

        "#{range.begin.strftime('%B %d, %Y')} - #{range.end.strftime('%B %d, %Y')}"
      end
    end

    def filter_by_time_range(interval, from = nil, to = nil)
      interval = interval&.to_sym
      if interval == :custom
        from_time = from.present? ? Time.zone.parse(from).beginning_of_day.to_i : 0
        to_time = to.present? ? Time.zone.parse(to).end_of_day.to_i : 253402300799
        where(time: from_time..to_time)
      elsif RANGES.key?(interval)
        public_send(interval)
      else
        all
      end
    end
  end
end
