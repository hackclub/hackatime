class AnonymizeUserService
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    ActiveRecord::Base.transaction do
      preserve_emails_for_ban_tracking
      anonymize_user_data
      destroy_associated_records
    end
  rescue StandardError => e
    Sentry.capture_exception(e, extra: { user_id: user.id })
    Rails.logger.error "AnonymizeUserService failed for user #{user.id}: #{e.message}"
    raise
  end

  private

  attr_reader :user

  def preserve_emails_for_ban_tracking
    user.email_addresses.update_all(
      user_id: user.id,
      source: EmailAddress.sources[:preserved_for_deletion]
    )
  end

  def anonymize_user_data
    user.update!(
      slack_uid: nil,
      slack_username: nil,
      slack_avatar_url: nil,
      slack_access_token: nil,
      slack_scopes: [],
      github_uid: nil,
      github_username: nil,
      github_avatar_url: nil,
      github_access_token: nil,
      hca_id: nil,
      hca_access_token: nil,
      hca_scopes: [],
      username: "deleted_user_#{user.id}",
      uses_slack_status: false,
      country_code: nil,

      deprecated_name: nil
    )
  end

  def destroy_associated_records
    user.api_keys.destroy_all
    user.admin_api_keys.destroy_all
    user.sign_in_tokens.destroy_all
    user.email_verification_requests.destroy_all
    user.wakatime_mirrors.destroy_all
    user.project_repo_mappings.destroy_all

    # tombstone
    Heartbeat.unscoped.where(user_id: user.id, deleted_at: nil).update_all(deleted_at: Time.current)

    WakatimeMirror.joins("INNER JOIN heartbeats ON heartbeats.id = wakatime_mirrors.heartbeat_id")
                  .where(heartbeats: { user_id: user.id })
                  .delete_all

    user.access_grants.destroy_all
    user.access_tokens.destroy_all
  end
end
