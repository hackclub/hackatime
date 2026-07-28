class Admin::TrustLevelAuditLogsController < Admin::BaseController
  before_action -> { require_admin_level!(:admin, :superadmin, :viewer) }

  def index
    @audit_logs = TrustLevelAuditLog.includes(:user, :changed_by)
                                   .recent
                                   .limit(250) # if there are more actions, fuck off man

    if params[:user_id].present?
      user = User.find_by(id: params[:user_id])
      if user
        @audit_logs = @audit_logs.for_user(user)
        @filtered_user = user
      end
    end

    if params[:admin_id].present?
      admin = User.find_by(id: params[:admin_id])
      if admin
        @audit_logs = @audit_logs.by_admin(admin)
        @filtered_admin = admin
      end
    end

    if params[:user_search].present?
      @user_search = params[:user_search].strip
      @audit_logs = @audit_logs.where(user_id: User.search_identity(@user_search).pluck(:id))
    end

    if params[:admin_search].present?
      @admin_search = params[:admin_search].strip
      @audit_logs = @audit_logs.where(changed_by_id: User.search_identity(@admin_search).pluck(:id))
    end

    if params[:trust_level_filter].present? && params[:trust_level_filter] != "all"
      case params[:trust_level_filter]
      when "to_convicted"
        @audit_logs = @audit_logs.where(new_trust_level: "red")
      when "to_trusted"
        @audit_logs = @audit_logs.where(new_trust_level: "green")
      when "to_suspected"
        @audit_logs = @audit_logs.where(new_trust_level: "yellow")
      when "to_unscored"
        @audit_logs = @audit_logs.where(new_trust_level: "blue")
      end
      @trust_level_filter = params[:trust_level_filter]
    end

    @audit_logs = @audit_logs.to_a
  end

  def show
    @audit_log = TrustLevelAuditLog.find(params[:id])
  end

  private
end
