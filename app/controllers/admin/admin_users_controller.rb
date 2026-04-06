class Admin::AdminUsersController < Admin::BaseController
  def index
    @current_user_id = current_user.id
    @ultraadmins = User.where(admin_level: :ultraadmin).order(:slack_username).to_a
    @superadmins = User.where(admin_level: :superadmin).order(:slack_username).to_a
    @admins = User.where(admin_level: :admin).order(:slack_username).to_a
    @viewers = User.where(admin_level: :viewer).order(:slack_username).to_a
  end

  def update
    @user = User.find(params[:id])
    new_level = params[:admin_level]

    if @user == current_user
      redirect_to admin_admin_users_path, alert: "You cannot change your own admin level."
      return
    end

    if new_level == "ultraadmin" && current_user.admin_level != "ultraadmin"
      redirect_to admin_admin_users_path, alert: "Only ultraadmins can grant the ultraadmin role."
      return
    end

    if @user.set_admin_level(new_level)
      redirect_to admin_admin_users_path, notice: "#{@user.display_name}'s admin level updated to #{new_level}."
    else
      redirect_to admin_admin_users_path, alert: "Failed to update admin level."
    end
  end

  def search
    query = params[:q].to_s.strip
    @users = if query.present?
      x = ActiveRecord::Base.sanitize_sql_like(query)
      User.where("slack_username ILIKE :q OR username ILIKE :q OR slack_uid ILIKE :q", q: "%#{x}%")
          .limit(20)
    else
      User.none
    end

    render partial: "search_results", locals: { users: @users }
  end
end
