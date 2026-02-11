module Api
  module V1
    class DashboardStatsController < ApplicationController
      include DashboardData

      before_action :require_session_user!

      def show
        render json: {
          filterable_dashboard_data: filterable_dashboard_data,
          activity_graph: activity_graph_data,
          today_stats: today_stats_data
        }
      end

      private

      def require_session_user!
        render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
      end
    end
  end
end
