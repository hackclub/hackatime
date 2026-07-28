module Api
  module Admin
    module V1
      class TrustLevelAuditLogsController < Api::Admin::V1::ApplicationController
        TRUST_LEVEL_FILTERS = {
          "to_convicted" => "red",
          "to_trusted" => "green",
          "to_suspected" => "yellow",
          "to_unscored" => "blue"
        }.freeze

        def index
          audit_logs = TrustLevelAuditLog.includes(:user, :changed_by).recent.limit(250)

          if params[:user_id].present?
            user = User.find_by(id: params[:user_id])
            return render_not_found_json("User not found") unless user
            audit_logs = audit_logs.for_user(user)
          end

          if params[:admin_id].present?
            admin = User.find_by(id: params[:admin_id])
            return render_not_found_json("Admin not found") unless admin
            audit_logs = audit_logs.by_admin(admin)
          end

          if params[:user_search].present?
            audit_logs = audit_logs.where(user_id: User.search_identity(params[:user_search]).pluck(:id))
          end

          if params[:admin_search].present?
            audit_logs = audit_logs.where(changed_by_id: User.search_identity(params[:admin_search]).pluck(:id))
          end

          if params[:trust_level_filter].present? && (level = TRUST_LEVEL_FILTERS[params[:trust_level_filter]])
            audit_logs = audit_logs.where(new_trust_level: level)
          end

          render json: {
            audit_logs: audit_logs.map { |log| audit_log_json(log) },
            total_count: audit_logs.count
          }
        end

        def show
          audit_log = TrustLevelAuditLog.find(params[:id])
          render json: audit_log_json(audit_log, full: true)
        rescue ActiveRecord::RecordNotFound
          render_not_found_json("Audit log not found")
        end

        private

        def audit_log_json(log, full: false)
          payload = {
            id: log.id,
            user: { id: log.user.id, username: log.user.username, display_name: log.user.display_name },
            previous_trust_level: log.previous_trust_level,
            new_trust_level: log.new_trust_level,
            changed_by: { id: log.changed_by.id, username: log.changed_by.username,
                          display_name: log.changed_by.display_name,
                          admin_level: log.changed_by.admin_level },
            reason: log.reason, notes: log.notes,
            created_at: log.created_at
          }
          if full
            payload[:user][:current_trust_level] = log.user.trust_level
            payload[:updated_at] = log.updated_at
          end
          payload
        end
      end
    end
  end
end
