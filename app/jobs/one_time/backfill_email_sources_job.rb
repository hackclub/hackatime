class OneTime::BackfillEmailSourcesJob < ApplicationJob
  queue_as :default

  def perform
    User.includes(:email_addresses).where(email_addresses: { source: nil }).find_each do |user|
      slack_info = user.raw_slack_user_info
      github_info = user.raw_github_user_info
      sleep 1 unless slack_info.nil? && github_info.nil?

      user.email_addresses.where(source: nil).each do |email_address|
        puts "Checking #{email_address.email} for #{user.id}"
        if slack_info&.dig("user", "profile", "email") == email_address.email
          email_address.update!(source: :slack)
          puts "Updated #{email_address.email} for #{user.id} to slack"
        elsif github_info&.dig("email") == email_address.email
          email_address.update!(source: :github)
          puts "Updated #{email_address.email} for #{user.id} to github"
        end
      end

      remaining = user.email_addresses.where(source: nil)
      if remaining.any?
        puts "Updating #{remaining.count} email addresses for #{user.id} to direct"
        remaining.update_all(source: :signing_in)
      end
    end
  end
end
