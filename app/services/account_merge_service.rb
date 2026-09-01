class AccountMergeService < ApplicationService
  DELETABLE_TABLES = %w[heartbeat_import_sources wakatime_mirrors project_labels].freeze

  class MergeError < StandardError; end

  def self.call(older_user:, newer_user:) = new(older_user:, newer_user:).call

  def initialize(older_user:, newer_user:)
    @older_user = older_user
    @newer_user = newer_user
  end

  def call
    results = []

    ActiveRecord::Base.transaction do
      results << "#{Heartbeat.where(user_id: newer_user.id).update_all(user_id: older_user.id)} heartbeats moved"
      results << "#{transfer_api_keys} API keys transferred"
      results << "#{newer_user.goals.update_all(user_id: older_user.id)} goals transferred"

      deleted_records = reconcile_instance_import_source

      revoked_tokens = newer_user.sign_in_tokens.destroy_all.count
      revoked_tokens += Doorkeeper::AccessToken.where(resource_owner_id: newer_user.id).update_all(revoked_at: Time.current)
      revoked_tokens += Doorkeeper::AccessGrant.where(resource_owner_id: newer_user.id).update_all(revoked_at: Time.current)
      results << "#{revoked_tokens} sessions/tokens revoked"

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

      newer_user.reload
      newer_user.destroy!
      results << "user ##{newer_user.id} deleted"
    end

    results.join(", ")
  rescue ActiveRecord::RecordNotUnique => error
    raise MergeError, "Destination account has conflicting records", cause: error
  end

  private

  attr_reader :older_user, :newer_user

  def transfer_api_keys
    transferred_count = 0
    reserved_names = older_user.api_keys.pluck(:name).index_with(true)

    ApiKey.where(user_id: newer_user.id).find_each do |api_key|
      api_key.update!(user: older_user, name: unique_api_key_name_for(reserved_names, api_key.name))
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

  def reconcile_instance_import_source
    newer_source = InstanceImportSource.find_by(user_id: newer_user.id)
    return 0 unless newer_source
    if InstanceImportSource.exists?(user_id: older_user.id)
      newer_source.destroy!; 1
    else
      newer_source.update!(user_id: older_user.id); 0
    end
  end

  def delete_rows(table_name, conditions)
    raise ArgumentError, "Table '#{table_name}' is not in the allowlist" unless DELETABLE_TABLES.include?(table_name)

    quoted = ActiveRecord::Base.connection.quote_table_name(table_name)
    sql = ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM #{quoted} WHERE user_id = ?", conditions.fetch(:user_id) ])
    ActiveRecord::Base.connection.delete(sql)
  end
end
