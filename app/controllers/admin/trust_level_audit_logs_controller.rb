class Admin::TrustLevelAuditLogsController < Admin::BaseController
  before_action :require_admin

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
      search_term = params[:user_search].strip
      user_ids = User.joins(:email_addresses)
                    .where("LOWER(users.username) LIKE ? OR LOWER(users.slack_username) LIKE ? OR LOWER(users.github_username) LIKE ? OR LOWER(email_addresses.email) LIKE ? OR CAST(users.id AS TEXT) LIKE ?",
                           "%#{search_term.downcase}%", "%#{search_term.downcase}%", "%#{search_term.downcase}%", "%#{search_term.downcase}%", "%#{search_term}%")
                    .pluck(:id)
      @audit_logs = @audit_logs.where(user_id: user_ids)
      @user_search = search_term
    end

    if params[:admin_search].present?
      search_term = params[:admin_search].strip
      admin_ids = User.joins(:email_addresses)
                     .where("LOWER(users.username) LIKE ? OR LOWER(users.slack_username) LIKE ? OR LOWER(users.github_username) LIKE ? OR LOWER(email_addresses.email) LIKE ? OR CAST(users.id AS TEXT) LIKE ?",
                            "%#{search_term.downcase}%", "%#{search_term.downcase}%", "%#{search_term.downcase}%", "%#{search_term.downcase}%", "%#{search_term}%")
                     .pluck(:id)
      @audit_logs = @audit_logs.where(changed_by_id: admin_ids)
      @admin_search = search_term
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

  def require_admin
    unless current_user && current_user.admin_level.in?([ "admin", "superadmin", "viewer" ])
      redirect_to root_path, alert: "no perms lmaooo"
    end
  end
end
