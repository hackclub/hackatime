ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "inertia_rails/minitest"
require_relative "support/clickhouse_test_database"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 2).to_i)

    # ClickHouse cannot roll back; ClickhouseTestDatabase truncates it instead.
    skip_transactional_tests_for_database :clickhouse

    parallelize_setup { |worker| ClickhouseTestDatabase.setup!(worker) }
    # Single-process runs (PARALLEL_WORKERS=1 or one test file) never call parallelize_setup.
    ClickhouseTestDatabase.setup! unless ENV.fetch("PARALLEL_WORKERS", 2).to_i > 1

    setup { ClickhouseTestDatabase.reset! }

    include FactoryBot::Syntax::Methods
  end
end

# A request runs with its own CurrentAttributes, so a heartbeat exclusion it
# creates or revokes resets only the request's snapshot. Drop the test's own
# snapshot afterwards so the test's later heartbeat reads see the change.
module ResetHeartbeatExclusionSnapshotAfterRequest
  def process(...)
    super
  ensure
    HeartbeatExclusion.reset_snapshot!
  end
end
ActionDispatch::Integration::Session.prepend(ResetHeartbeatExclusionSnapshotAfterRequest)

module SystemTestAuthHelper
  def sign_in_as(user)
    email = user.email_addresses.first!
    visit dev_log_me_in_path(email: email.email)
  end
end

module IntegrationTestAuthHelper
  def sign_in_as(user)
    token = create(:sign_in_token, user: user, auth_type: :email)
    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]
  end
end

class ActionDispatch::IntegrationTest
  include IntegrationTestAuthHelper
end
