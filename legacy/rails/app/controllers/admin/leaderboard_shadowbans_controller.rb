class Admin::LeaderboardShadowbansController < InertiaController
  layout "inertia"

  before_action :require_shadowban_admin!

  def index
    render inertia: "Admin/LeaderboardShadowbans", props: {
      shadowbanned_users: shadowbanned_users.map { |user| LeaderboardShadowbanSerializer.call(user) }
    }
  end

  def search_users
    query_term = params[:query].to_s.strip
    return render json: [] if query_term.blank?

    users = User.fuzzy_ranked_search(query_term, limit: 20).includes(LeaderboardShadowbanSerializer::PRELOADS)
    render json: users.map { |user| LeaderboardShadowbanSerializer.call(user) }
  end

  def create
    user = User.find_by(id: params[:user_id])
    return redirect_to(admin_leaderboard_shadowbans_path, alert: "User not found.") unless user

    if user.set_leaderboard_shadowban(banned: true, changed_by_user: current_user, reason: params[:reason], expires_at: params[:leaderboard_shadowban_expires_at])
      redirect_to admin_leaderboard_shadowbans_path, notice: "#{user.display_name} is now hidden from leaderboards."
    else
      redirect_to admin_leaderboard_shadowbans_path, alert: shadowban_error(user, "Could not leaderboard shadowban that user.")
    end
  end

  def destroy
    user = User.find_by(id: params[:user_id])
    return redirect_to(admin_leaderboard_shadowbans_path, alert: "User not found.") unless user

    if user.set_leaderboard_shadowban(banned: false, changed_by_user: current_user)
      redirect_to admin_leaderboard_shadowbans_path, notice: "#{user.display_name} is visible on leaderboards again."
    else
      redirect_to admin_leaderboard_shadowbans_path, alert: shadowban_error(user, "Could not remove that leaderboard shadowban.")
    end
  end

  private

  def require_shadowban_admin!
    unless current_user&.can_leaderboard_shadowban_users?
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end

  def shadowbanned_users
    User.leaderboard_shadowbanned
      .includes(LeaderboardShadowbanSerializer::PRELOADS)
      .order(updated_at: :desc)
  end

  def shadowban_error(user, fallback)
    user.errors.any? ? user.errors.full_messages.to_sentence : fallback
  end
end
