module TimeRangeFilterable
  extend ActiveSupport::Concern

  STANDARD_RANGES = {
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
    }
  }.freeze

  EVENTS_CONFIG_PATH = Rails.root.join("config", "events.json").freeze

  EVENT_DEFINITIONS = JSON.parse(File.read(EVENTS_CONFIG_PATH)).freeze

  # mahad says: NEVER remove entries from the events JSON
  # if you need to get rid of an event, add a retired flag or something
  EVENT_KEYS = EVENT_DEFINITIONS.keys.sort.map(&:to_sym).freeze

  EVENT_RANGES = EVENT_DEFINITIONS.each_with_object({}) do |(key, cfg), memo|
    timezone = cfg["timezone"]
    starts_at = cfg["starts_at"]
    ends_at = cfg["ends_at"]
    memo[key.to_sym] = {
      human_name: cfg["human_name"],
      calculate: -> {
        Time.use_zone(timezone) do
          Time.zone.parse(starts_at).beginning_of_day..Time.zone.parse(ends_at).end_of_day
        end
      }
    }
  end.freeze

  RANGES = STANDARD_RANGES.merge(EVENT_RANGES).freeze

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
