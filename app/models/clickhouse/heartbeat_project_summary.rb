module Clickhouse
  class HeartbeatProjectSummary < Clickhouse::Record
    self.table_name = "heartbeat_project_summaries"
    self.primary_key = nil

    class << self
      def seconds_for(user_id:, project:)
        where(user_id: user_id, project: Array(project).map(&:to_s)).sum(:seconds).to_f.round
      end

      def heartbeat_count_for(user_id:, project:)
        where(user_id: user_id, project: Array(project).map(&:to_s)).sum(:heartbeat_count).to_i
      end

      def durations_for(user_id:)
        where(user_id: user_id).group(:project).sum(:seconds).transform_values { |seconds| seconds.to_f.round }
      end

      def durations_for_users(user_ids)
        ids = Array(user_ids).map(&:to_i).uniq
        return {} if ids.empty?

        where(user_id: ids)
          .group(:user_id, :project)
          .sum(:seconds)
          .each_with_object({}) do |((user_id, project), seconds), result|
            (result[user_id.to_i] ||= {})[project] = seconds.to_f.round
          end
      end
    end
  end
end
