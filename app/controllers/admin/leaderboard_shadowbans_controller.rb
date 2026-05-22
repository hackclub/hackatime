class Admin::LeaderboardShadowbansController < InertiaController
  layout "inertia"

  before_action :require_shadowban_admin!

  def show
    render inertia: "Admin/LeaderboardShadowbans", props: {
      shadowbanned_users: shadowbanned_users.map { |user| format_user(user) }
    }
  end

  def search_users
    query_term = params[:query].to_s.downcase.strip
    return render json: [] if query_term.blank?

    users = User.search_identity(query_term)
      .includes(:email_addresses)
      .select(
        "users.*, " \
        "CASE WHEN LOWER(users.username) = #{ActiveRecord::Base.connection.quote(query_term)} " \
        "THEN 0 ELSE 1 END AS exact_match_rank"
      )
      .order(Arel.sql("exact_match_rank ASC, users.username ASC"))
      .limit(20)

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

  def format_user(user)
    {
      id: user.id,
      display_name: user.display_name,
      avatar_url: user.avatar_url,
      created_at: user.created_at&.strftime("%Y-%m-%d"),
      username: user.username,
      email: user.email_addresses.first&.email,
      leaderboard_shadowbanned: user.leaderboard_shadowbanned?,
      leaderboard_shadowban_reason: user.leaderboard_shadowban_reason,
      updated_at: user.updated_at&.strftime("%Y-%m-%d %H:%M UTC")
    }
  end
end
