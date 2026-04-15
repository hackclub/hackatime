class OneTime::SetUserTimezoneFromSlackJob < ApplicationJob
  queue_as :default

  def perform
    User.where.not(slack_uid: nil).find_each(batch_size: 100) do |user|
      begin
        Users::SlackIntegrationService.new(user).set_timezone_from_slack
        user.save!
      rescue => e
        report_error(e, message: "Failed to update timezone for user #{user.id}")
      end
    end
  end
end
