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

module InertiaTestHelper
  def inertia_page
    document = Nokogiri::HTML(response.body)
    page_script = document.at_css("script[data-page='app'][type='application/json']")
    assert_not_nil page_script, "Expected Inertia page payload script in response body"
    JSON.parse(page_script.text)
  end

  def assert_inertia_component(expected_component)
    page = inertia_page
    assert_equal expected_component, page["component"],
      "Expected Inertia component '#{expected_component}' but got '#{page["component"]}'"
  end

  def assert_inertia_prop(key, expected_value)
    page = inertia_page
    actual = page.dig("props", key)
    if expected_value.nil?
      assert_nil actual, "Expected Inertia prop '#{key}' to be nil but got #{actual.inspect}"
    else
      assert_equal expected_value, actual,
        "Expected Inertia prop '#{key}' to be #{expected_value.inspect} but got #{actual.inspect}"
    end
  end
end

class ActionDispatch::IntegrationTest
  include InertiaTestHelper
end
