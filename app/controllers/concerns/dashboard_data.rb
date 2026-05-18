module DashboardData
  extend ActiveSupport::Concern

  private

  def dashboard_stats_payload
    dashboard_payload.payload(programming_goals_progress: programming_goals_progress_data)
  end

  def filterable_dashboard_data
    dashboard_payload.filterable_dashboard_data
  end

  def activity_graph_data
    dashboard_payload.activity_graph_data
  end

  def today_stats_data
    dashboard_payload.today_stats_data
  end

  def dashboard_rollup_eligible?
    DashboardData::Payload.new(user: current_user, params: params).rollup_eligible?
  end

  def dashboard_rollups_available?
    DashboardData::Payload.new(user: current_user, params: params).rollups_available?
  end

  def dashboard_live_raw_filter_options
    dashboard_payload.send(:live_raw_filter_options)
  end

  def dashboard_project_grouped_durations(scope)
    DashboardData::Snapshots.project_grouped_durations(scope)
  end

  def dashboard_payload
    @dashboard_payload ||= DashboardData::Payload.new(
      user: current_user,
      params: params,
      rollup_rows: @dashboard_rollup_rows
    )
  end
end
