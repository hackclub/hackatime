class Admin::AccountMergerController < InertiaController
  layout "inertia"

  before_action :authorize_account_merger!

  def show
    render inertia: "Admin/AccountMerger"
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

    results = users.map { |user| format_user(user) }

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
  rescue => e
    Rails.logger.error("Account merge failed and was rolled back: #{e.message}")
    redirect_to admin_account_merger_path, alert: "Merge failed and was rolled back: #{e.message}"
  end

  private

  # Centralized admin-area gate via Pundit. The action_name maps to a
  # policy predicate (`access?` for show, `search_users?`, `merge?`) —
  # all are ultraadmin-only.
  #
  # We rescue NotAuthorizedError locally to preserve the legacy
  # "redirect to root with alert" UX rather than the default
  # ApplicationController#user_not_authorized behavior.
  def authorize_account_merger!
    action = action_name == "show" ? :access? : "#{action_name}?".to_sym
    authorize :account_merger, action
  rescue Pundit::NotAuthorizedError
    redirect_to root_path, alert: "You are not authorized to access this page."
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

  def perform_merge(older_user, newer_user)
    results = []

    ActiveRecord::Base.transaction do
      # 1. Move heartbeats from newer to older
      heartbeat_count = Heartbeat.where(user_id: newer_user.id).update_all(user_id: older_user.id)
      results << "#{heartbeat_count} heartbeats moved"

      # 2. Transfer API keys from newer to older
      api_key_count = transfer_api_keys(older_user:, newer_user:)
      results << "#{api_key_count} API keys transferred"

      # 3. Transfer goals from newer to older
      goal_count = newer_user.goals.update_all(user_id: older_user.id)
      results << "#{goal_count} goals transferred"

      # 4. Reconcile instance import sources before deleting the newer user.
      deleted_records = reconcile_instance_import_source(older_user:, newer_user:)

      # 5. Revoke newer user's sessions
      revoked_tokens = 0
      revoked_tokens += newer_user.sign_in_tokens.destroy_all.count
      revoked_tokens += Doorkeeper::AccessToken.where(resource_owner_id: newer_user.id).update_all(revoked_at: Time.current)
      revoked_tokens += Doorkeeper::AccessGrant.where(resource_owner_id: newer_user.id).update_all(revoked_at: Time.current)
      results << "#{revoked_tokens} sessions/tokens revoked"

      # 6. Delete all related data for the newer user
      deleted_records += newer_user.email_addresses.destroy_all.count
      deleted_records += newer_user.email_verification_requests.destroy_all.count
      deleted_records += newer_user.goals.destroy_all.count
      deleted_records += newer_user.admin_api_keys.destroy_all.count
      deleted_records += ProjectRepoMapping.where(user_id: newer_user.id).delete_all
      deleted_records += newer_user.heartbeat_import_runs.destroy_all.count
      deleted_records += delete_rows("heartbeat_import_sources", user_id: newer_user.id)
      deleted_records += delete_rows("wakatime_mirrors", user_id: newer_user.id)
      deleted_records += Commit.where(user_id: newer_user.id).delete_all
      deleted_records += RepoHostEvent.where(user_id: newer_user.id).delete_all
      deleted_records += TrustLevelAuditLog.where(user_id: newer_user.id).delete_all
      deleted_records += TrustLevelAuditLog.where(changed_by_id: newer_user.id).delete_all
      deleted_records += DeletionRequest.where(user_id: newer_user.id).delete_all
      deleted_records += LeaderboardEntry.where(user_id: newer_user.id).delete_all
      deleted_records += Doorkeeper::Application.where(owner_id: newer_user.id, owner_type: "User").destroy_all.count
      Doorkeeper::AccessToken.where(resource_owner_id: newer_user.id).delete_all
      Doorkeeper::AccessGrant.where(resource_owner_id: newer_user.id).delete_all
      deleted_records += delete_rows("project_labels", user_id: newer_user.id.to_s)
      deleted_records += PaperTrail::Version.where(item_type: "User", item_id: newer_user.id).delete_all
      results << "#{deleted_records} related records cleaned up"

      # 7. Finally, delete the newer user
      newer_user.reload
      newer_user.destroy!
      results << "user ##{newer_user.id} deleted"
    end

    results.join(", ")
  end

  DELETABLE_TABLES = %w[heartbeat_import_sources wakatime_mirrors project_labels].freeze

  def transfer_api_keys(older_user:, newer_user:)
    transferred_count = 0
    reserved_names = older_user.api_keys.pluck(:name).index_with(true)

    ApiKey.where(user_id: newer_user.id).find_each do |api_key|
      api_key.update!(
        user: older_user,
        name: unique_api_key_name_for(reserved_names, api_key.name)
      )

      transferred_count += 1
    end

    transferred_count
  end

  def unique_api_key_name_for(reserved_names, original_name)
    unless reserved_names[original_name]
      reserved_names[original_name] = true
      return original_name
    end

    suffix = " (transferred)"
    candidate_name = "#{original_name}#{suffix}"
    counter = 2

    while reserved_names[candidate_name]
      candidate_name = "#{original_name}#{suffix} #{counter}"
      counter += 1
    end

    reserved_names[candidate_name] = true
    candidate_name
  end

  def reconcile_instance_import_source(older_user:, newer_user:)
    newer_source = InstanceImportSource.find_by(user_id: newer_user.id)
    return 0 unless newer_source

    if InstanceImportSource.exists?(user_id: older_user.id)
      newer_source.destroy!
      1
    else
      newer_source.update!(user_id: older_user.id)
      0
    end
  end

  def delete_rows(table_name, conditions)
    sql = case table_name
    when "heartbeat_import_sources"
      ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM heartbeat_import_sources WHERE user_id = ?", conditions.fetch(:user_id) ])
    when "wakatime_mirrors"
      ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM wakatime_mirrors WHERE user_id = ?", conditions.fetch(:user_id) ])
    when "project_labels"
      ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM project_labels WHERE user_id = ?", conditions.fetch(:user_id) ])
    else
      raise ArgumentError, "Table '#{table_name}' is not in the allowlist"
    end

    ActiveRecord::Base.connection.delete(sql)
  end
end
