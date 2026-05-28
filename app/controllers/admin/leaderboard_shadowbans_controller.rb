class Admin::LeaderboardShadowbansController < InertiaController
  layout "inertia"

  before_action :require_shadowban_admin!

  def index
    users = shadowbanned_users.to_a
    actors_by_user_id = shadowban_actors_by_user_id(users)

    render inertia: "Admin/LeaderboardShadowbans", props: {
      shadowbanned_users: users.map { |user| format_user(user, shadowbanned_by: actors_by_user_id[user.id]) }
    }
  end

  def search_users
    query_term = params[:query].to_s.strip
    return render json: [] if query_term.blank?

    users = User.fuzzy_ranked_search(query_term, limit: 20).includes(:email_addresses)
    render json: users.map { |user| format_user(user) }
  end

  def create
    user = User.find_by(id: params[:user_id])
    unless user
      redirect_to admin_leaderboard_shadowbans_path, alert: "User not found."
      return
    end

    unless user.set_leaderboard_shadowban(
      banned: true,
      changed_by_user: current_user,
      reason: params[:reason]
    )
      redirect_to admin_leaderboard_shadowbans_path, alert: "Could not leaderboard shadowban that user."
      return
    end

    redirect_to admin_leaderboard_shadowbans_path, notice: "#{user.display_name} is now hidden from leaderboards."
  end

  def destroy
    user = User.find_by(id: params[:user_id])
    unless user
      redirect_to admin_leaderboard_shadowbans_path, alert: "User not found."
      return
    end

    unless user.set_leaderboard_shadowban(banned: false, changed_by_user: current_user)
      redirect_to admin_leaderboard_shadowbans_path, alert: "Could not remove that leaderboard shadowban."
      return
    end

    redirect_to admin_leaderboard_shadowbans_path, notice: "#{user.display_name} is visible on leaderboards again."
  end

  private

  def require_shadowban_admin!
    unless current_user&.can_leaderboard_shadowban_users?
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end

  def shadowbanned_users
    User.where(leaderboard_shadowbanned: true)
      .includes(:email_addresses)
      .order(updated_at: :desc)
      .limit(100)
  end

  def shadowban_actors_by_user_id(users)
    actor_ids_by_user_id = {}

    PaperTrail::Version
      .where(item_type: "User", item_id: users.map(&:id))
      .where.not(whodunnit: nil)
      .order(created_at: :desc)
      .each do |version|
        user_id = version.item_id
        next if actor_ids_by_user_id.key?(user_id)
        next unless version.object_changes.to_s.include?("leaderboard_shadowbanned:\n- false\n- true")

        actor_ids_by_user_id[user_id] = version.whodunnit.to_i
      end

    actors = User.where(id: actor_ids_by_user_id.values).includes(:email_addresses).index_by(&:id)
    actor_ids_by_user_id.transform_values { |actor_id| actors[actor_id] }.compact
  end

  def format_user(user, shadowbanned_by: nil)
    {
      id: user.id,
      display_name: user.display_name,
      avatar_url: user.avatar_url,
      created_at: user.created_at&.strftime("%Y-%m-%d"),
      username: user.username,
      email: user.email_addresses.first&.email,
      leaderboard_shadowbanned: user.leaderboard_shadowbanned?,
      leaderboard_shadowban_reason: user.leaderboard_shadowban_reason,
      shadowbanned_by: shadowbanned_by && {
        id: shadowbanned_by.id,
        display_name: shadowbanned_by.display_name,
        username: shadowbanned_by.username,
        email: shadowbanned_by.email_addresses.first&.email
      },
      updated_at: user.updated_at&.strftime("%Y-%m-%d %H:%M UTC")
    }
  end
end
