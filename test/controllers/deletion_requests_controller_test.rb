require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

class DeletionRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as(@user)
  end

  test "create immediately creates a request when HCA is not linked" do
    assert_difference "DeletionRequest.count", 1 do
      post create_deletion_path, params: deletion_params
    end

    assert_redirected_to deletion_path
  end

  test "create requires HCA step-up when HCA is linked" do
    @user.update!(hca_id: "hca-linked")

    assert_no_difference "DeletionRequest.count" do
      post create_deletion_path, params: deletion_params, headers: { "X-Inertia" => "true" }
    end

    assert_response :conflict
    authorize_uri = URI.parse(response.headers.fetch("X-Inertia-Location"))
    authorize_query = Rack::Utils.parse_query(authorize_uri.query)
    assert_equal "#{HCAService.host}/oauth/authorize", "#{authorize_uri.scheme}://#{authorize_uri.host}#{authorize_uri.path}"
    assert_equal "login", authorize_query["prompt"]
    assert_includes authorize_query["scope"].split, "openid"
    assert_equal session.dig(:pending_deletion_request, "state"), authorize_query["state"]
    assert_equal @user.id, session.dig(:pending_deletion_request, "user_id")
    assert_equal "hca-linked", session.dig(:pending_deletion_request, "hca_id")
    assert_equal deletion_params[:deletion_request][:reason], session.dig(:pending_deletion_request, "attributes", "reason")
  end

  test "create rejects deletion details that cannot fit in the session" do
    @user.update!(hca_id: "hca-linked")

    post create_deletion_path, params: {
      deletion_request: deletion_params[:deletion_request].merge(reason_details: "a" * 10_000)
    }

    assert_redirected_to my_settings_path
    assert_equal "Deletion details are too long.", flash[:alert]
    assert_nil session[:pending_deletion_request]
  end

  test "HCA callback creates the pending request for the linked identity" do
    @user.update!(hca_id: "hca-linked")
    post create_deletion_path, params: deletion_params
    state = session.dig(:pending_deletion_request, "state")
    stub_hca_identity("hca-linked")

    assert_difference "DeletionRequest.count", 1 do
      get hca_deletion_callback_path, params: { code: "step-up-code", state: state }
    end

    assert_redirected_to deletion_path
    assert_equal deletion_params[:deletion_request][:reason], DeletionRequest.last.reason
    assert_nil session[:pending_deletion_request]
  end

  test "HCA callback rejects a different identity" do
    @user.update!(hca_id: "hca-linked")
    post create_deletion_path, params: deletion_params
    state = session.dig(:pending_deletion_request, "state")
    stub_hca_identity("hca-someone-else")

    assert_no_difference "DeletionRequest.count" do
      get hca_deletion_callback_path, params: { code: "step-up-code", state: state }
    end

    assert_redirected_to my_settings_path
  end

  test "HCA callback handles an invalid response" do
    @user.update!(hca_id: "hca-linked")
    post create_deletion_path, params: deletion_params
    state = session.dig(:pending_deletion_request, "state")
    stub_request(:post, "#{HCAService.host}/oauth/token").to_return(body: "not json")

    assert_no_difference "DeletionRequest.count" do
      get hca_deletion_callback_path, params: { code: "step-up-code", state: state }
    end

    assert_redirected_to my_settings_path
    assert_equal "Hack Club Auth verification failed. Please try again.", flash[:alert]
  end

  test "HCA callback handles a connection failure" do
    @user.update!(hca_id: "hca-linked")
    post create_deletion_path, params: deletion_params
    state = session.dig(:pending_deletion_request, "state")
    stub_request(:post, "#{HCAService.host}/oauth/token")
      .to_raise(HTTP::ConnectionError.new("HCA unavailable"))

    assert_no_difference "DeletionRequest.count" do
      get hca_deletion_callback_path, params: { code: "step-up-code", state: state }
    end

    assert_redirected_to my_settings_path
    assert_equal "Hack Club Auth verification failed. Please try again.", flash[:alert]
  end

  test "HCA callback rejects an invalid state" do
    @user.update!(hca_id: "hca-linked")
    post create_deletion_path, params: deletion_params

    assert_no_difference "DeletionRequest.count" do
      get hca_deletion_callback_path, params: { code: "step-up-code", state: "wrong-state" }
    end

    assert_redirected_to my_settings_path
    assert_nil session[:pending_deletion_request]
  end

  test "HCA callback cannot be replayed" do
    @user.update!(hca_id: "hca-linked")
    post create_deletion_path, params: deletion_params
    state = session.dig(:pending_deletion_request, "state")
    stub_hca_identity("hca-linked")
    get hca_deletion_callback_path, params: { code: "step-up-code", state: state }

    assert_no_difference "DeletionRequest.count" do
      get hca_deletion_callback_path, params: { code: "step-up-code", state: state }
    end

    assert_redirected_to my_settings_path
  end

  test "HCA callback rejects a changed linked identity" do
    @user.update!(hca_id: "hca-linked")
    post create_deletion_path, params: deletion_params
    state = session.dig(:pending_deletion_request, "state")
    @user.update!(hca_id: "hca-changed")

    assert_no_difference "DeletionRequest.count" do
      get hca_deletion_callback_path, params: { code: "step-up-code", state: state }
    end

    assert_redirected_to my_settings_path
  end

  test "HCA callback rechecks deletion eligibility" do
    @user.update!(hca_id: "hca-linked")
    post create_deletion_path, params: deletion_params
    state = session.dig(:pending_deletion_request, "state")
    DeletionRequest.create_for_user!(@user)
    stub_hca_identity("hca-linked")

    assert_no_difference "DeletionRequest.count" do
      get hca_deletion_callback_path, params: { code: "step-up-code", state: state }
    end

    assert_redirected_to my_settings_path
  end

  test "HCA error must include the pending state" do
    @user.update!(hca_id: "hca-linked")
    post create_deletion_path, params: deletion_params

    get hca_deletion_callback_path, params: { error: "access_denied", state: "wrong-state" }

    assert_redirected_to my_settings_path
    assert_equal "Hack Club Auth verification failed. Please try again.", flash[:alert]
  end

  private

  def deletion_params
    {
      deletion_request: {
        reason: "Something else",
        reason_details: "I no longer need my account"
      }
    }
  end

  def stub_hca_identity(hca_id)
    stub_request(:post, "#{HCAService.host}/oauth/token")
      .with(body: hash_including("code" => "step-up-code", "redirect_uri" => hca_deletion_callback_url))
      .to_return(body: { access_token: "step-up-token" }.to_json)
    stub_request(:get, "#{HCAService.host}/api/v1/me")
      .with(headers: { "Authorization" => "Bearer step-up-token" })
      .to_return(body: { identity: { id: hca_id } }.to_json)
  end
end
