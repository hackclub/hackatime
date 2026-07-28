ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "nokogiri"
require "json"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 2).to_i)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    self.fixture_table_names -= [
      "mailing_addresses",
      "physical_mails",
      "api_keys",
      "heartbeats",
      "users",
      "email_addresses",
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

module SystemTestAuthHelper
  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    visit auth_token_path(token: token.token)
  end
end

module IntegrationTestAuthHelper
  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]
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
  include IntegrationTestAuthHelper
  include InertiaTestHelper
end
