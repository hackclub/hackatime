class AnonymizeUserService < ApplicationService
  ANONYMIZE_FIELDS = %i[
    slack_uid slack_username slack_avatar_url slack_access_token
    github_uid github_username github_avatar_url github_access_token
    hca_id hca_access_token country_code deprecated_name display_name_override
    profile_bio profile_github_url profile_twitter_url profile_bluesky_url
    profile_linkedin_url profile_discord_url profile_website_url
  ].freeze

  def self.call(user) = new(user).call

  def initialize(user)
    @user = user
  end

  def call
    ActiveRecord::Base.transaction do
      user.email_addresses.update_all(user_id: user.id, source: EmailAddress.sources[:preserved_for_deletion])
      user.update!(ANONYMIZE_FIELDS.index_with { nil }.merge(
        slack_scopes: [], hca_scopes: [],
        username: "deleted_user_#{user.id}", uses_slack_status: false
      ))
      destroy_associated_records
    end
  rescue StandardError => e
    report_error(e, message: "AnonymizeUserService failed for user #{user.id}", extra: { user_id: user.id })
    raise
  end

  private

  attr_reader :user

  def destroy_associated_records
    user.api_keys.destroy_all
    user.admin_api_keys.destroy_all
    user.sign_in_tokens.destroy_all
    user.email_verification_requests.destroy_all
    # tables still *exist* but model files were removed; delete records manually.
    %w[wakatime_mirrors heartbeat_import_sources].each do |t|
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql([ "DELETE FROM #{t} WHERE user_id = ?", user.id ])
      )
    end
    user.heartbeat_import_runs.destroy_all
    user.project_repo_mappings.destroy_all
    user.goals.destroy_all
    Heartbeat.unscoped.where(user_id: user.id, deleted_at: nil).update_all(deleted_at: Time.current)
    user.access_grants.destroy_all
    user.access_tokens.destroy_all
  end
end
