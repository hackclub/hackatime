class Admin::AdminUsersController < Admin::BaseController
  include AdminLevelChangeMessages

  def index
    render inertia: "Admin/AdminUsers", props: {
      groups: -> { admin_groups },
      current_user_id: current_user.id,
      search_results: InertiaRails.optional { search_results }
    }
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

  private

  def inertia_layout_props = super.merge(full_width: true)

  def admin_groups
    levels = %w[ultraadmin superadmin admin viewer]
    users = User.where(admin_level: levels).order(:slack_username).to_a
    keys = AdminApiKey.active.where(user_id: users.map(&:id)).order(:created_at).group_by(&:user_id)
    groups = users.group_by(&:admin_level)
    levels.to_h do |level|
      [ level, groups.fetch(level, []).map { |user| serialize_user(user, keys: keys.fetch(user.id, [])) } ]
    end
  end

  def search_results
    query = params[:q].to_s.strip
    users = query.present? ? User.fuzzy_ranked_search(query, limit: 20) : User.none
    { query: query, users: users.map { |user| serialize_user(user, all_actions: true) } }
  end

  def serialize_user(user, all_actions: false, keys: nil)
    levels = all_actions ? %w[ultraadmin superadmin admin viewer] : %w[ultraadmin superadmin admin viewer default]
    { id: user.id, display_name: user.display_name, avatar_url: user.avatar_url, slack_uid: user.slack_uid,
      admin_level: user.admin_level, allowed_levels: levels.select { |level| current_user.can_change_admin_level_of?(user, level) },
      admin_api_keys: keys&.map { |key| serialize_key(key) } }.compact
  end

  def serialize_key(key)
    { id: key.id, name: key.name, token_preview: "#{key.token_preview}...",
      last_used_at: key.last_used_at&.in_time_zone&.strftime("%b %d, %Y at %I:%M %p %Z") }
  end
end
