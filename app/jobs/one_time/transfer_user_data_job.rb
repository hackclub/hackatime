class OneTime::TransferUserDataJob < ApplicationJob
  queue_as :default

  SLACK_FIELDS = %w[slack_uid slack_avatar_url slack_scopes slack_access_token].freeze
  GITHUB_FIELDS = %w[github_uid github_avatar_url github_access_token github_username].freeze

  def perform(source_user_id, target_user_id, dry_run: true)
    @source_user_id = source_user_id
    @target_user_id = target_user_id

    ActiveRecord::Base.transaction do
      EmailAddress.where(user_id: @source_user_id).update_all(user_id: @target_user_id)
      transfer_api_keys
      Heartbeat.where(user_id: @source_user_id).update_all(user_id: @target_user_id)
      (SLACK_FIELDS + GITHUB_FIELDS).each { |f| target_user[f] ||= source_user.send(f) }

      source_user.slack_uid = nil if target_user.slack_uid.present?
      source_user.github_uid = nil if target_user.github_uid.present?
      source_user.save!
      target_user.save!

      raise ActiveRecord::Rollback if dry_run
    end
  end

  private

  def transfer_api_keys
    ApiKey.where(user_id: @source_user_id).find_each do |api_key|
      api_key.name = "#{api_key.name} (transferred)" if target_user.api_keys.exists?(name: api_key.name)
      api_key.user_id = @target_user_id
      api_key.save!
    end
  end

  def source_user = @source_user ||= User.find(@source_user_id)
  def target_user = @target_user ||= User.find(@target_user_id)
end
