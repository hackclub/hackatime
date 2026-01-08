module Api
  module Admin
    module V1
      class TrustLevelAuditLogsController < Api::Admin::V1::ApplicationController
        def index
          audit_logs = TrustLevelAuditLog.includes(:user, :changed_by)
                                        .recent
                                        .limit(250)

          # Filter by user_id
          if params[:user_id].present?
            user = User.find_by(id: params[:user_id])
            if user
              audit_logs = audit_logs.for_user(user)
            else
              return render json: { error: "User not found" }, status: :not_found
            end
          end

          # Filter by admin_id (changed_by)
          if params[:admin_id].present?
            admin = User.find_by(id: params[:admin_id])
            if admin
              audit_logs = audit_logs.by_admin(admin)
            else
              return render json: { error: "Admin not found" }, status: :not_found
            end
          end

          # Search by user
          if params[:user_search].present?
            user_ids = User.search_identity(params[:user_search]).pluck(:id)
            audit_logs = audit_logs.where(user_id: user_ids)
          end

          # Search by admin
          if params[:admin_search].present?
            admin_ids = User.search_identity(params[:admin_search]).pluck(:id)
            audit_logs = audit_logs.where(changed_by_id: admin_ids)
          end

          # Filter by trust level
          if params[:trust_level_filter].present? && params[:trust_level_filter] != "all"
            case params[:trust_level_filter]
            when "to_convicted"
              audit_logs = audit_logs.where(new_trust_level: "red")
            when "to_trusted"
              audit_logs = audit_logs.where(new_trust_level: "green")
            when "to_suspected"
              audit_logs = audit_logs.where(new_trust_level: "yellow")
            when "to_unscored"
              audit_logs = audit_logs.where(new_trust_level: "blue")
            end
          end

          render json: {
            audit_logs: audit_logs.map do |log|
              {
                id: log.id,
                user: {
                  id: log.user.id,
                  username: log.user.username,
                  display_name: log.user.display_name
                },
                previous_trust_level: log.previous_trust_level,
                new_trust_level: log.new_trust_level,
                changed_by: {
                  id: log.changed_by.id,
                  username: log.changed_by.username,
                  display_name: log.changed_by.display_name,
                  admin_level: log.changed_by.admin_level
                },
                reason: log.reason,
                notes: log.notes,
                created_at: log.created_at
              }
            end,
            total_count: audit_logs.count
          }
        end

        def show
          audit_log = TrustLevelAuditLog.find(params[:id])

          render json: {
            id: audit_log.id,
            user: {
              id: audit_log.user.id,
              username: audit_log.user.username,
              display_name: audit_log.user.display_name,
              current_trust_level: audit_log.user.trust_level
            },
            previous_trust_level: audit_log.previous_trust_level,
            new_trust_level: audit_log.new_trust_level,
            changed_by: {
              id: audit_log.changed_by.id,
              username: audit_log.changed_by.username,
              display_name: audit_log.changed_by.display_name,
              admin_level: audit_log.changed_by.admin_level
            },
            reason: audit_log.reason,
            notes: audit_log.notes,
            created_at: audit_log.created_at,
            updated_at: audit_log.updated_at
          }
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Audit log not found" }, status: :not_found
        end
      end
    end
  end
end
