ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "inertia_rails/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: ENV.fetch("PARALLEL_WORKERS", 2).to_i)

    include FactoryBot::Syntax::Methods
  end
end

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
