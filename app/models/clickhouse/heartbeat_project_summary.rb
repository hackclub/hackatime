module Clickhouse
  class HeartbeatProjectSummary < Clickhouse::Record
    self.table_name = "heartbeat_project_summaries"
    self.primary_key = nil

    class << self
      def seconds_for(user_id:, project:)
        where(user_id: user_id, project: encoded_projects(project)).sum(:seconds).to_f.round
      end

      def heartbeat_count_for(user_id:, project:)
        where(user_id: user_id, project: encoded_projects(project)).sum(:heartbeat_count).to_i
      end

      def durations_for(user_id:)
        decode_durations(where(user_id: user_id).group(:project).sum(:seconds))
      end

      def durations_for_users(user_ids)
        ids = Array(user_ids).map(&:to_i).uniq
        return {} if ids.empty?

        where(user_id: ids)
          .group(:user_id, :project)
          .sum(:seconds)
          .each_with_object({}) do |((user_id, project), seconds), result|
            decoded_project = HeartbeatIntervals.decode_project(project)
            (result[user_id.to_i] ||= {})[decoded_project] = seconds.to_f.round
          end
      end

      private

      def encoded_projects(projects)
        values = projects.is_a?(Array) ? projects : [ projects ]
        values.map { |project| HeartbeatIntervals.encode_project(project) }
      end

      def decode_durations(durations)
        durations.to_h do |project, seconds|
          [ HeartbeatIntervals.decode_project(project), seconds.to_f.round ]
        end
      end
    end
  end
end
