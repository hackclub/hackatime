module Clickhouse
  class StatsReader
    DIMENSION_FILTERS = %i[language editor operating_system machine category entity branch].freeze

    def initialize(user, repository: nil)
      @user_id = user.respond_to?(:id) ? user.id : user
      @repository = repository || ServingRepository.new
    end

    def total_seconds(start_time: nil, end_time: nil, filters: {})
      normalized_filters = filters.compact_blank.symbolize_keys
      date_range = date_range_for(start_time, end_time)
      return 0 if date_range == false

      if normalized_filters.empty?
        return repository.total_seconds(user_id:, date_range:)
      end

      if normalized_filters.keys == [ :project ]
        return repository.total_seconds(
          user_id:, date_range:, filters: { project: single_filter_value!(normalized_filters[:project]) }
        )
      end

      dimension = (normalized_filters.keys & DIMENSION_FILTERS).first
      if dimension && normalized_filters.keys == [ dimension ]
        return repository.total_seconds(
          user_id:, date_range:,
          filters: { dimension => single_filter_value!(normalized_filters[dimension]) }
        )
      end

      raise ArgumentError, "Unsupported serving-table filter combination: #{normalized_filters.keys.join(", ")}"
    end

    def project_seconds(project)
      repository.project_seconds(user_id:, project:)
    end

    def project_durations(start_time: nil, end_time: nil)
      date_range = date_range_for(start_time, end_time)
      return {} if date_range == false

      repository.project_durations(user_id:, date_range:)
    end

    def dimension_durations(dimension:, start_time: nil, end_time: nil)
      date_range = date_range_for(start_time, end_time)
      return {} if date_range == false

      repository.dimension_durations(user_id:, dimension:, date_range:)
    end

    def filter_durations(dimension:, start_time: nil, end_time: nil)
      date_range = date_range_for(start_time, end_time)
      return {} if date_range == false

      repository.filter_durations(user_id:, dimension:, date_range:)
    end

    def days_with_heartbeats(start_time:, end_time:)
      date_range = date_range_for(start_time, end_time)
      return 0 if date_range == false || date_range.empty?

      repository.days_with_heartbeats(user_id:, date_range:)
    end

    def project_dimension_durations(project:, dimension:, start_time: nil, end_time: nil)
      date_range = date_range_for(start_time, end_time)
      return {} if date_range == false

      repository.project_dimension_durations(user_id:, project:, dimension:, date_range:)
    end

    def project_dimension_value_count(project:, dimension:, start_time: nil, end_time: nil)
      date_range = date_range_for(start_time, end_time)
      return 0 if date_range == false

      repository.project_dimension_value_count(user_id:, project:, dimension:, date_range:)
    end

    def language_summary(start_time: nil, end_time: nil)
      date_range = date_range_for(start_time, end_time)
      return { total_seconds: 0, languages: {} } if date_range == false

      repository.language_summary(user_id:, date_range:)
    end

    def project_stats(project:, dimensions:, include_total: true, start_time: nil, end_time: nil)
      date_range = date_range_for(start_time, end_time)
      return { total_seconds: 0, dimensions: {} } if date_range == false

      repository.project_stats(user_id:, project:, date_range:, dimensions:, include_total:)
    end

    private

    attr_reader :user_id, :repository

    def single_filter_value!(value)
      values = Array(value)
      raise ArgumentError, "Serving tables require a single filter value" unless values.one?

      values.first
    end

    def date_range_for(start_time, end_time)
      return {} if start_time.nil? || end_time.nil?

      start_at = to_time(start_time)
      end_at = to_time(end_time)
      return false if end_at <= start_at

      start_date = start_at.to_date
      end_date = (end_at - 0.000001).to_date
      return false if end_date < start_date

      { start_date: start_date, end_date: end_date }
    end

    def to_time(value)
      case value
      when Date then value.in_time_zone
      when Time, ActiveSupport::TimeWithZone then value
      else Time.zone.at(value.to_f)
      end
    end
  end
end
