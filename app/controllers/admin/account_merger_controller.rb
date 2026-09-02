class Admin::AccountMergerController < InertiaController
  layout "inertia"

  before_action :require_ultraadmin!

  def show = render(inertia: "Admin/AccountMerger")

  def search_users
    query_term = params[:query].to_s.strip
    return render json: [] if query_term.blank?

    users = User.fuzzy_ranked_search(query_term, limit: 20).includes(:email_addresses)
    render json: users.map { |user| format_user(user) }
  end

  def merge
    older_id = params[:older_id].to_i
    newer_id = params[:newer_id].to_i

    return merge_error("Cannot merge a user into themselves.") if older_id == newer_id

    older_user = User.find_by(id: older_id)
    newer_user = User.find_by(id: newer_id)

    return merge_error("One or both users not found.") unless older_user && newer_user
    return merge_error("You cannot merge your own account.") if older_user == current_user || newer_user == current_user

    privileged = [ older_user, newer_user ].select { |u| u.admin_level != "default" }
    if privileged.any?
      names = privileged.map { |u| "#{u.display_name} (#{u.admin_level})" }.to_sentence
      return merge_error("Refusing to merge accounts with elevated admin_level: #{names}. Demote them to `default` first.")
    end

    if newer_user.created_at < older_user.created_at
      return merge_error("The NEWER user (right side) must have been created after the OLDER user (left side). #{newer_user.display_name} was created #{newer_user.created_at.to_date} which is before #{older_user.display_name} created #{older_user.created_at.to_date}.")
    end

    begin
      merge_results = AccountMergeService.call(older_user:, newer_user:)
    rescue AccountMergeService::MergeError => error
      report_merge_failure(error, older_user:, newer_user:)
      return merge_error("Merge failed and was rolled back. Check the application logs for details.")
    rescue StandardError => error
      report_merge_failure(error, older_user:, newer_user:)
      raise
    end

    redirect_to admin_account_merger_path, notice: "Merge complete! #{merge_results}"
  end

  private

  def merge_error(message) = redirect_to(admin_account_merger_path, alert: message)

  def report_merge_failure(exception, older_user:, newer_user:)
    diagnostic = exception.cause || exception
    report_error(
      exception,
      message: "Account merge failed and was rolled back for older user ##{older_user.id} and newer user ##{newer_user.id}: #{diagnostic.class}: #{diagnostic.message}",
      extra: { older_user_id: older_user.id, newer_user_id: newer_user.id }
    )
  end

  def format_user(user)
    {
      id: user.id,
      display_name: user.display_name,
      avatar_url: user.avatar_url,
      created_at: user.created_at&.strftime("%Y-%m-%d"),
      username: user.username,
      email: user.email_addresses.first&.email
    }
  end
end
