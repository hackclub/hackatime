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

    audit_logs = @audit_logs.to_a
    render inertia: "Admin/TrustLevelAuditLogs/Index", props: {
      audit_logs: audit_logs.map { |log| audit_log_props(log) },
      filters: { user_search: @user_search, admin_search: @admin_search, trust_level: @trust_level_filter || "all" },
      filtered_user: @filtered_user&.display_name,
      filtered_admin: @filtered_admin&.display_name
    }
  end

  def show
    log = TrustLevelAuditLog.includes(:user, :changed_by).find(params[:id])
    render inertia: "Admin/TrustLevelAuditLogs/Show", props: { audit_log: audit_log_props(log).merge(notes: log.notes) }
  end

  private

  def audit_log_props(log)
    {
      id: log.id, created_at: log.created_at.strftime("%b %d, %Y at %I:%M %p"),
      created_at_long: log.created_at.strftime("%B %d, %Y at %I:%M %p %Z"),
      previous_trust_level: log.previous_trust_level, new_trust_level: log.new_trust_level,
      reason: log.reason, user: audit_user_props(log.user), changed_by: audit_user_props(log.changed_by)
    }
  end

  def audit_user_props(user)
    { id: user.id, display_name: user.display_name.to_s, avatar_url: user.avatar_url, admin_level: user.admin_level }
  end
end
