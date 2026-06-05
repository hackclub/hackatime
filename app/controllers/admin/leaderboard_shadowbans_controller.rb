class Admin::LeaderboardShadowbansController < InertiaController
  layout "inertia"

  before_action :require_shadowban_admin!

  def index
    users = shadowbanned_users.to_a

    render inertia: "Admin/LeaderboardShadowbans", props: {
      shadowbanned_users: users.map { |user| format_user(user, shadowbanned_by: user.leaderboard_shadowbanned_by) }
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

    expires_at = parsed_expiration
    if invalid_expiration?
      redirect_to admin_leaderboard_shadowbans_path, alert: "Automatic unshadowban time is invalid."
      return
    end

    unless user.set_leaderboard_shadowban(
      banned: true,
      changed_by_user: current_user,
      reason: params[:reason],
      expires_at: expires_at
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
      .includes(:email_addresses, :leaderboard_shadowbanned_by)
      .order(updated_at: :desc)
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
      leaderboard_shadowban_expires_at: user.leaderboard_shadowban_expires_at&.iso8601,
      leaderboard_shadowban_expires_at_formatted: user.leaderboard_shadowban_expires_at&.strftime("%b %-d, %Y at %H:%M UTC"),
      shadowbanned_by: shadowbanned_by && {
        id: shadowbanned_by.id,
        display_name: shadowbanned_by.display_name,
        username: shadowbanned_by.username,
        avatar_url: shadowbanned_by.avatar_url,
        admin_level: shadowbanned_by.admin_level
      },
      updated_at: user.updated_at&.strftime("%b %-d, %Y at %H:%M UTC")
    }
  end

  def parsed_expiration
    value = params[:leaderboard_shadowban_expires_at].to_s.strip
    return nil if value.blank?

    Time.zone.parse(value).tap { |parsed| @invalid_expiration = true unless parsed }
  rescue ArgumentError
    @invalid_expiration = true
    nil
  end

  def invalid_expiration?
    @invalid_expiration
  end
end
