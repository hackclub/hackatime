class ProfileStatsService
  PROFILE_DASHBOARD_KEYS = %w[
    total_time total_heartbeats project_durations language_stats editor_stats
    operating_system_stats category_stats weekly_project_stats language_colors
    top_project top_language top_editor top_operating_system top_category
    singular_project singular_language singular_editor singular_operating_system singular_category
  ].to_set.freeze

  attr_reader :user

  def initialize(user)
    @user = user
  end

  def dashboard_stats
    @dashboard_stats ||= {
      filterable_dashboard_data: stats.filterable_dashboard_data.select { |k, _| PROFILE_DASHBOARD_KEYS.include?(k.to_s) },
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

  def stats
    @stats ||= DashboardStats.new(user: user)
  end

  def week_seconds(activity_graph)
    week_start, week_end = Time.use_zone(user.timezone) { [ Date.current.beginning_of_week, Date.current.end_of_week ] }
    (activity_graph[:duration_by_date] || {}).sum do |date, seconds|
      d = date.is_a?(Date) ? date : (Date.parse(date.to_s) rescue nil)
      (d && d >= week_start && d <= week_end) ? seconds.to_i : 0
    end
  end
end
