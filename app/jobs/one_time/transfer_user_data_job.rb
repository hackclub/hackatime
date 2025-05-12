class OneTime::TransferUserDataJob < ApplicationJob
  queue_as :default

  def perform(source_user_id, target_user_id)
    @source_user_id = source_user_id
    @target_user_id = target_user_id

    ActiveRecord::Base.transaction do
      transfer_email_addresses
      transfer_api_keys
      transfer_heartbeats
      transfer_slack_data
      transfer_github_data

      source_user.slack_uid = nil if target_user.slack_uid.present?
      source_user.github_uid = nil if target_user.github_uid.present?

      source_user.save!

      target_user.save!
    end
  end

  private

  def transfer_email_addresses
    EmailAddress.where(user_id: @source_user_id).update_all(user_id: @target_user_id)
  end

  def transfer_api_keys
    ApiKey.where(user_id: @source_user_id).find_each do |api_key|
      # If target user already has an API key with this name, append a suffix
      if target_user.api_keys.exists?(name: api_key.name)
        api_key.name = "#{api_key.name} (transferred)"
      end
      api_key.user_id = @target_user_id
      api_key.save!
    end
  end

  def transfer_heartbeats
    Heartbeat.where(user_id: @source_user_id).update_all(user_id: @target_user_id)
  end

  def source_user
    @source_user ||= User.find(@source_user_id)
  end

  def target_user
    @target_user ||= User.find(@target_user_id)
  end

  def transfer_slack_data
    fields = %w[slack_uid slack_avatar_url slack_scopes slack_access_token]

    fields.each do |field|
      target_user[field] ||= source_user.send(field)
    end
  end

  def transfer_github_data
    fields = %w[github_uid github_avatar_url github_access_token github_username]

    fields.each do |field|
      target_user[field] ||= source_user.send(field)
    end
  end
end
