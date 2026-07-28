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
    stardance:        { human_name: "Stardance",        calculate: -> { TimeRangeFilterable.datetime_range("2026-05-30 09:00:00", "2026-08-30 23:59:59") } },
    flavortown:       { human_name: "Flavortown",       calculate: -> { TimeRangeFilterable.event_range("2025-12-15", "2026-04-30") } },
    summer_of_making: { human_name: "Summer of Making", calculate: -> { TimeRangeFilterable.event_range("2025-06-16", "2025-09-30") } },
    high_seas:        { human_name: "High Seas",        calculate: -> { TimeRangeFilterable.event_range("2024-10-30", "2025-01-31") } },
    low_skies:        { human_name: "Low Skies",        calculate: -> { TimeRangeFilterable.event_range("2024-10-3",  "2025-01-12") } },
    scrapyard:        { human_name: "Scrapyard Global", calculate: -> { TimeRangeFilterable.event_range("2025-03-14", "2025-03-17") } }
  }.freeze

  def self.event_range(from_date, to_date, timezone: "America/New_York")
    Time.use_zone(timezone) do
      Time.zone.parse(from_date).beginning_of_day..Time.zone.parse(to_date).end_of_day
    end
  end

  def self.datetime_range(from_datetime, to_datetime, timezone: "America/New_York")
    Time.use_zone(timezone) do
      Time.zone.parse(from_datetime)..Time.zone.parse(to_datetime)
    end
  end

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
