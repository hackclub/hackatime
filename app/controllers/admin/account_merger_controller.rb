class Admin::AccountMergerController < InertiaController
  layout "inertia"

  before_action :require_ultraadmin!

  def show
    render inertia: "Admin/AccountMerger", props: {
      search_url: admin_account_merger_search_users_path,
      merge_url: admin_account_merger_merge_path
    }
  end

  def search_users
    query_term = params[:query].to_s.downcase.strip
    return render json: [] if query_term.blank?

    user_id_match = nil
    if query_term.match?(/^\d+$/)
      user_id = query_term.to_i
      user_id_match = User.where(id: user_id).first
    end

    if user_id_match
      results = [ format_user(user_id_match) ]
    else
      users = User.where(
        "LOWER(username) LIKE :query OR LOWER(slack_username) LIKE :query OR CAST(id AS TEXT) LIKE :query OR EXISTS (SELECT 1 FROM email_addresses WHERE email_addresses.user_id = users.id AND LOWER(email_addresses.email) LIKE :query)",
        query: "%#{query_term}%"
      )
        .order(Arel.sql("CASE WHEN LOWER(username) = #{ActiveRecord::Base.connection.quote(query_term)} THEN 0 ELSE 1 END, username ASC"))
        .limit(20)
        .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url, :created_at)

      results = users.map { |user| format_user(user) }
    end

    render json: results
  end

  def merge
    older_id = params[:older_id].to_i
    newer_id = params[:newer_id].to_i

    if older_id == newer_id
      redirect_to admin_account_merger_path, alert: "Cannot merge a user into themselves."
      return
    end

    older_user = User.find_by(id: older_id)
    newer_user = User.find_by(id: newer_id)

    unless older_user && newer_user
      redirect_to admin_account_merger_path, alert: "One or both users not found."
      return
    end

    if newer_user.created_at < older_user.created_at
      redirect_to admin_account_merger_path, alert: "The NEWER user (right side) must have been created after the OLDER user (left side). #{newer_user.display_name} was created #{newer_user.created_at.to_date} which is before #{older_user.display_name} created #{older_user.created_at.to_date}."
      return
    end

    merge_results = perform_merge(older_user, newer_user)

    redirect_to admin_account_merger_path, notice: "Merge complete! #{merge_results}"
  end

  private

  def require_ultraadmin!
    unless current_user&.admin_level == "ultraadmin"
      redirect_to root_path, alert: "You are not authorized to access this page."
    end
  end

  def format_user(user)
    {
      id: user.id,
      display_name: user.respond_to?(:display_name) ? user.display_name : user.username,
      avatar_url: user.respond_to?(:avatar_url) ? user.avatar_url : nil,
      created_at: user.created_at&.strftime("%Y-%m-%d"),
      username: user.username,
      email: user.respond_to?(:email_addresses) ? user.email_addresses.first&.email : nil
    }
  end

  def perform_merge(older_user, newer_user)
    results = []

    # 1. Move heartbeats from newer to older
    heartbeat_count = Heartbeat.where(user_id: newer_user.id).update_all(user_id: older_user.id)
    results << "#{heartbeat_count} heartbeats moved"

    # 2. Transfer API keys from newer to older
    api_key_count = ApiKey.where(user_id: newer_user.id).update_all(user_id: older_user.id)
    results << "#{api_key_count} API keys transferred"

    # 3. Transfer goals from newer to older
    goal_count = newer_user.goals.update_all(user_id: older_user.id)
    results << "#{goal_count} goals transferred"

    # 4. Revoke newer user's sessions (sign_in_tokens, access_tokens, access_grants)
    revoked_tokens = 0
    begin
      revoked_tokens += newer_user.sign_in_tokens.destroy_all.count
    rescue => e
      Rails.logger.error("Failed to destroy sign_in_tokens: #{e.message}")
    end
    begin
      revoked_tokens += Doorkeeper::AccessToken.where(resource_owner_id: newer_user.id).update_all(revoked_at: Time.current)
    rescue => e
      Rails.logger.error("Failed to revoke access_tokens: #{e.message}")
    end
    begin
      revoked_tokens += Doorkeeper::AccessGrant.where(resource_owner_id: newer_user.id).update_all(revoked_at: Time.current)
    rescue => e
      Rails.logger.error("Failed to revoke access_grants: #{e.message}")
    end
    results << "#{revoked_tokens} sessions/tokens revoked"

    # 5. Delete all related data for the newer user
    deleted_records = 0

    begin
      deleted_records += newer_user.email_addresses.destroy_all.count
    rescue => e
      Rails.logger.error("Failed to destroy email_addresses: #{e.message}")
    end

    begin
      deleted_records += newer_user.email_verification_requests.destroy_all.count
    rescue => e
      Rails.logger.error("Failed to destroy email_verification_requests: #{e.message}")
    end

    begin
      deleted_records += newer_user.goals.destroy_all.count
    rescue => e
      Rails.logger.error("Failed to destroy goals: #{e.message}")
    end

    begin
      deleted_records += newer_user.admin_api_keys.destroy_all.count
    rescue => e
      Rails.logger.error("Failed to destroy admin_api_keys: #{e.message}")
    end

    begin
      deleted_records += ProjectRepoMapping.where(user_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy project_repo_mappings: #{e.message}")
    end

    begin
      deleted_records += newer_user.heartbeat_import_runs.destroy_all.count
    rescue => e
      Rails.logger.error("Failed to destroy heartbeat_import_runs: #{e.message}")
    end

    begin
      deleted_records += HeartbeatImportSource.where(user_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy heartbeat_import_sources: #{e.message}")
    end

    begin
      deleted_records += InstanceImportSource.where(user_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy instance_import_sources: #{e.message}")
    end

    begin
      deleted_records += WakatimeMirror.where(user_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy wakatime_mirrors: #{e.message}")
    end

    begin
      deleted_records += Commit.where(user_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy commits: #{e.message}")
    end

    begin
      deleted_records += RepoHostEvent.where(user_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy repo_host_events: #{e.message}")
    end

    begin
      deleted_records += TrustLevelAuditLog.where(user_id: newer_user.id).delete_all
      deleted_records += TrustLevelAuditLog.where(changed_by_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy trust_level_audit_logs: #{e.message}")
    end

    begin
      deleted_records += DeletionRequest.where(user_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy deletion_requests: #{e.message}")
    end

    begin
      deleted_records += LeaderboardEntry.where(user_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy leaderboard_entries: #{e.message}")
    end

    begin
      deleted_records += Doorkeeper::Application.where(owner_id: newer_user.id, owner_type: "User").destroy_all.count
    rescue => e
      Rails.logger.error("Failed to destroy oauth_applications: #{e.message}")
    end

    begin
      deleted_records += Doorkeeper::AccessToken.where(resource_owner_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy access_tokens: #{e.message}")
    end
    begin
      deleted_records += Doorkeeper::AccessGrant.where(resource_owner_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy access_grants: #{e.message}")
    end

    begin
      deleted_records += ProjectLabel.where(user_id: newer_user.id.to_s).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy project_labels: #{e.message}")
    end

    begin
      deleted_records += PaperTrail::Version.where(item_type: "User", item_id: newer_user.id).delete_all
    rescue => e
      Rails.logger.error("Failed to destroy versions: #{e.message}")
    end

    results << "#{deleted_records} related records cleaned up"

    # 6. Finally, delete the newer user
    begin
      newer_user.reload
      newer_user.destroy!
      results << "user ##{newer_user.id} deleted"
    rescue => e
      Rails.logger.error("Failed to destroy newer user: #{e.message}")
      results << "FAILED to delete user ##{newer_user.id}: #{e.message}"
    end

    results.join(", ")
  end
end
