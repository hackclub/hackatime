class ProfileStatsService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  # Returns the same shape consumed by Home/SignedIn.svelte so the profile
  # page can render <Dashboard />, <ActivityGraph />, etc. directly.
  def dashboard_stats
    @dashboard_stats ||= {
      filterable_dashboard_data: stats.filterable_dashboard_data,
      activity_graph: stats.activity_graph_data,
      today_stats: stats.today_stats_data
    }
  end

  # Minimal payload used by the OG image generator.
  def og_stats
    return nil unless user

    fdd = stats.filterable_dashboard_data
    return nil if fdd.blank?

    {
      total_time_all: fdd[:total_time].to_i,
      total_time_week: week_seconds(stats.activity_graph_data),
      top_language: fdd["top_language"]
    }
  end

  private

  def stats
    @stats ||= DashboardStats.new(user: user)
  end

  def week_seconds(activity_graph)
    duration_by_date = activity_graph[:duration_by_date] || {}
    week_start = Date.current.beginning_of_week
    week_end = Date.current.end_of_week

    duration_by_date.sum do |date, seconds|
      d = parse_date(date)
      (d && d >= week_start && d <= week_end) ? seconds.to_i : 0
    end
  end

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
