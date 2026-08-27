require "test_helper"

class RateLimitedTestController < ActionController::API
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  self.cache_store = RATE_LIMIT_STORE

  before_action :authenticate
  include AuthenticatedApiRateLimiting

  def index = render json: { ok: true }

  private

  def authenticate
    @user_id = request.headers["X-User-ID"]
    head :unauthorized unless @user_id
  end

  def authenticated_api_rate_limit_identity = "user:#{@user_id}"
end

class AuthenticatedApiRateLimitingTest < ActionController::TestCase
  tests RateLimitedTestController

  setup do
    RateLimitedTestController::RATE_LIMIT_STORE.clear
    @request.headers["X-User-ID"] = "1"
  end

  test "returns the compatible response after 300 requests and resets on the next minute" do
    travel_to Time.utc(2026, 8, 27, 12, 0, 30) do
      300.times do
        get :index
        assert_response :success
      end

      get :index

      assert_response :too_many_requests
      assert_equal "30", response.headers["Retry-After"]
      assert_equal "300", response.headers["X-RateLimit-Limit"]
      assert_equal "0", response.headers["X-RateLimit-Remaining"]
      assert_equal Time.utc(2026, 8, 27, 12, 1).to_i.to_s, response.headers["X-RateLimit-Reset"]
      assert_equal "2026-08-27T12:01:00+00:00", response.headers["X-RateLimit-Reset-At"]
      assert_equal({
        "error" => "Rate limit exceeded",
        "message" => "Woah there, way too fast, take a chill pill speedy gonzales!",
        "retry_after" => 30,
        "reset_at" => "2026-08-27T12:01:00+00:00"
      }, response.parsed_body)

      travel 30.seconds
      get :index
      assert_response :success
    end
  end

  test "does not limit requests safelisted by Rack Attack" do
    301.times do
      @request.set_header("rack.attack.match_type", :safelist)
      get :index
      assert_response :success
    end
  end
end
