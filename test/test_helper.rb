ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    self.fixture_table_names -= [
      "mailing_addresses",
      "physical_mails",
      "api_keys",
      "heartbeats",
      "project_repo_mappings",
      "repositories",
      "sailors_log_leaderboards",
      "sailors_log_notification_preferences",
      "sailors_log_slack_notifications",
      "sailors_logs"
    ]

    # Add more helper methods to be used by all tests here...
  end
end
