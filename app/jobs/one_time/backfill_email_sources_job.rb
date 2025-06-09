class OneTime::BackfillEmailSourcesJob < ApplicationJob
  queue_as :default

  def perform
    # Backfill email addresses from Slack

    users.find_each do |user|
      slack_user_info = user.raw_slack_user_info
      github_user_info = user.raw_github_user_info

      # sleep if we hit an api
      sleep 1 unless slack_user_info.nil? && github_user_info.nil?

      user.email_addresses.where(source: nil).each do |email_address|
        puts "Checking #{email_address.email} for #{user.id}"
        if slack_user_info&.dig("user", "profile", "email") == email_address.email
          email_address.update!(source: :slack)
          puts "Updated #{email_address.email} for #{user.id} to slack"
        elsif github_user_info&.dig("email") == email_address.email
          email_address.update!(source: :github)
          puts "Updated #{email_address.email} for #{user.id} to github"
        end
      end

      other_addresses = user.email_addresses.where(source: nil)
      if other_addresses.any?
        puts "Updating #{other_addresses.count} email addresses for #{user.id} to direct"
        other_addresses.update_all(source: :signing_in)
      end
    end
  end

  private

  def users
    # any user with email addresses that don't have a source
    @users ||= User.includes(:email_addresses)
                   .where(email_addresses: { source: nil })
  end
end
