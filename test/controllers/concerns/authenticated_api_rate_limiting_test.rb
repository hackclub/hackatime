require "test_helper"

class RateLimitedTestController < ActionController::API
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  IDENTITIES = { "Bearer user-token" => "user:1", "Bearer admin-token" => "admin_api_key:1" }.freeze

  self.cache_store = RATE_LIMIT_STORE

  before_action :authenticate, except: :optional
  before_action :authenticate_optionally, only: :optional
  include AuthenticatedApiRateLimiting

  def index = render json: { ok: true }
  def optional = render json: { ok: true }

  private

  def authenticate
    authenticate_optionally
    head :unauthorized unless @identity
  end

  def authenticate_optionally = @identity = IDENTITIES[request.headers["Authorization"]]

  def authenticated_api_rate_limit_identity = @identity
  def admin_api_rate_limit? = @identity&.start_with?("admin_api_key:")
end

class AuthenticatedApiRateLimitingTest < ActionController::TestCase
  tests RateLimitedTestController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "index", to: "rate_limited_test#index"
      get "optional", to: "rate_limited_test#optional"
    end
    RateLimitedTestController::RATE_LIMIT_STORE.clear
    @request.headers["Authorization"] = "Bearer user-token"
  end

  test "returns the compatible response after 600 user requests and resets on the next minute" do
    travel_to Time.utc(2026, 8, 27, 12, 0, 30) do
      600.times do
        get :index
        assert_response :success
      end

      get :index

      assert_response :too_many_requests
      assert_equal "30", response.headers["Retry-After"]
      assert_equal "600", response.headers["X-RateLimit-Limit"]
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

  test "allows admin credentials 5000 requests per minute" do
    @request.headers["Authorization"] = "Bearer admin-token"

    travel_to Time.utc(2026, 8, 27, 12, 0, 30) do
      5000.times { get :index }
      assert_response :success

      get :index
      assert_response :too_many_requests
      assert_equal "5000", response.headers["X-RateLimit-Limit"]
    end
  end

  test "keeps admin and user allowances separate" do
    travel_to Time.utc(2026, 8, 27, 12, 0, 30) do
      600.times { get :index }

      @request.headers["Authorization"] = "Bearer admin-token"
      get :index
      assert_response :success
    end
  end

  test "does not limit requests safelisted by Rack Attack" do
    601.times do
      @request.set_header("rack.attack.match_type", :safelist)
      get :index
      assert_response :success
    end
  end

  test "limits rejected credentials by IP before authentication" do
    @request.headers["Authorization"] = "Bearer wrong"

    travel_to Time.utc(2026, 8, 27, 12, 0, 30) do
      300.times do
        get :index
        assert_response :unauthorized
      end

      get :index
      assert_response :too_many_requests
      assert_equal "30", response.headers["Retry-After"]
      assert_equal "300", response.headers["X-RateLimit-Limit"]

      @request.headers["Authorization"] = "Bearer user-token"
      get :index
      assert_response :too_many_requests

      travel 30.seconds
      get :index
      assert_response :success
    end
  end

  test "counts credentials an optionally authenticated action ignores as rejected" do
    @request.headers["Authorization"] = "Bearer wrong"

    travel_to Time.utc(2026, 8, 27, 12, 0, 30) do
      300.times do
        get :optional
        assert_response :success
      end

      get :optional
      assert_response :too_many_requests
    end
  end

  test "leaves requests without credentials to Rack Attack" do
    @request.headers["Authorization"] = nil

    301.times { get :index }
    assert_response :unauthorized

    301.times { get :optional }
    assert_response :success
  end

  test "does not count successful requests as rejected credentials" do
    travel_to Time.utc(2026, 8, 27, 12, 0, 30) do
      299.times { get :index }

      @request.headers["Authorization"] = "Bearer wrong"
      get :index
      assert_response :unauthorized
    end
  end

  test "does not limit rejected credentials safelisted by Rack Attack" do
    @request.headers["Authorization"] = "Bearer wrong"

    301.times do
      @request.set_header("rack.attack.match_type", :safelist)
      get :index
      assert_response :unauthorized
    end
  end
end
