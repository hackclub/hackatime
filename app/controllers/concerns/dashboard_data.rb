module DashboardData
  extend ActiveSupport::Concern

  private

  def filterable_dashboard_data
    dashboard_stats.filterable_dashboard_data
  end

  def activity_graph_data
    dashboard_stats.activity_graph_data
  end

  def today_stats_data
    dashboard_stats.today_stats_data
  end

  def dashboard_filters
    DashboardStats::FILTERS
  end

  def dashboard_stats
    @dashboard_stats ||= DashboardStats.new(user: current_user, params: params)
  end
end
