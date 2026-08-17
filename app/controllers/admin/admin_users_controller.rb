class Admin::AdminUsersController < Admin::BaseController
  include AdminLevelChangeMessages

  def index
    groups = %w[ultraadmin superadmin admin viewer].to_h do |level|
      [ level, User.where(admin_level: level).order(:slack_username).map { |user| serialize_user(user) } ]
    end
    render inertia: "Admin/AdminUsers", props: { groups: groups, current_user_id: current_user.id }
  end

  def update
    @user = User.find(params[:id])
    new_level = params[:admin_level]

    unless current_user.can_change_admin_level_of?(@user, new_level)
      return redirect_to(admin_admin_users_path, alert: admin_level_change_denial_message(@user, new_level))
    end

    if @user.set_admin_level(new_level, changed_by_user: current_user)
      redirect_to admin_admin_users_path, notice: "#{@user.display_name}'s admin level updated to #{new_level}."
    else
      redirect_to admin_admin_users_path, alert: "Failed to update admin level."
    end
  end

  def search
    query = params[:q].to_s.strip
    users = query.present? ? User.fuzzy_ranked_search(query, limit: 20) : User.none
    render json: { users: users.map { |user| serialize_user(user, all_actions: true) } }
  end

  private

  def serialize_user(user, all_actions: false)
    levels = all_actions ? %w[ultraadmin superadmin admin viewer] : %w[ultraadmin superadmin admin viewer default]
    { id: user.id, display_name: user.display_name, avatar_url: user.avatar_url, slack_uid: user.slack_uid,
      admin_level: user.admin_level, allowed_levels: levels.select { |level| current_user.can_change_admin_level_of?(user, level) } }
  end
end
