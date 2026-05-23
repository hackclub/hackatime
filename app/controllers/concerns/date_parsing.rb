# frozen_string_literal: true

# Shared timestamp/date parsing helpers used by API endpoints that accept
# `start_date`/`end_date` (or arbitrary date params).
# Hosts must also include RenderHelpers (or define render_error).
module DateParsing
  extend ActiveSupport::Concern

  # Parses start_date/end_date params with defaults; returns a Range[start_ts..end_ts]
  # or nil after rendering an error.
  def parse_default_time_range
    start_ts = parse_ts(params[:start_date], :start_date, :start, default: 10.years.ago.utc.to_i)
    return nil if performed?
    end_ts = parse_ts(params[:end_date], :end_date, :end, default: Date.current.end_of_day.utc.to_i)
    return nil if performed?
    start_ts..end_ts
  end

  # Returns nil if the response was already rendered (parse failure); otherwise
  # returns the query with start/end time filters applied (from params[:start_date], params[:end_date]).
  def apply_time_range(query)
    if params[:start_date].present?
      ts = parse_ts(params[:start_date], :start_date, :start)
      return nil if performed?
      query = query.where("time >= ?", ts)
    end
    if params[:end_date].present?
      ts = parse_ts(params[:end_date], :end_date, :end)
      return nil if performed?
      query = query.where("time <= ?", ts)
    end
    query
  end

  # Unified timestamp parser. Returns integer epoch seconds or renders an error.
  def parse_ts(raw, field_name, boundary, default: nil)
    return default if raw.blank?
    value = raw.to_s.strip

    if value.match?(/\A\d+\z/)
      ts = value.to_i
      ts /= 1000 if ts >= 1_000_000_000_000
      return ts if ts.between?(0, 253_402_300_799)
    else
      begin
        d = Date.parse(value)
        return boundary == :end ? d.end_of_day.to_i : d.beginning_of_day.to_i
      rescue Date::Error, ArgumentError
      end
    end

    render_error("invalid #{field_name}")
  end

  # Default-to-current date param parser. Renders error on invalid date.
  def parse_date_param_default
    return Date.current if params[:date].blank?
    Date.parse(params[:date])
  rescue Date::Error, ArgumentError
    render_error("Invalid date.")
  end
end
