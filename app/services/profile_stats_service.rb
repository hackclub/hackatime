class ProfileStatsService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def dashboard_stats
    @dashboard_stats ||= {
      filterable_dashboard_data: filterable_dashboard_data_for_profile,
      activity_graph: stats.activity_graph_data
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

  # Keys Dashboard.svelte actually reads when filters are hidden.
  PROFILE_DASHBOARD_KEYS = %i[
    total_time
    total_heartbeats
    project_durations
    language_stats
    editor_stats
    operating_system_stats
    category_stats
    weekly_project_stats
    language_colors
  ].freeze

  PROFILE_DASHBOARD_TOP_KEYS = %w[
    top_project
    top_language
    top_editor
    top_operating_system
    top_category
    singular_project
    singular_language
    singular_editor
    singular_operating_system
    singular_category
  ].freeze

  def filterable_dashboard_data_for_profile
    full = stats.filterable_dashboard_data
    PROFILE_DASHBOARD_KEYS.each_with_object({}) { |k, h| h[k] = full[k] if full.key?(k) }
      .merge(PROFILE_DASHBOARD_TOP_KEYS.each_with_object({}) { |k, h| h[k] = full[k] if full.key?(k) })
  end

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
