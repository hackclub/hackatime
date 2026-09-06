require "test_helper"

class Api::Admin::V1::RouteOwnershipTest < ActionDispatch::IntegrationTest
  test "legacy user utility paths dispatch to resource controllers" do
    assert_route :get, "/api/admin/v1/user/info", "users", "user_info"
    assert_route :get, "/api/admin/v1/user/info_batch", "users", "user_info_batch"
    assert_route :get, "/api/admin/v1/user/stats", "users", "user_stats"
    assert_route :get, "/api/admin/v1/user/projects", "users", "user_projects"
    assert_route :post, "/api/admin/v1/user/get_user_by_email", "users", "get_user_by_email"
    assert_route :post, "/api/admin/v1/user/search_fuzzy", "users", "search_users_fuzzy"

    assert_route :get, "/api/admin/v1/user/heartbeats", "heartbeats", "user_heartbeats"
    assert_route :get, "/api/admin/v1/user/heartbeat_values", "heartbeats", "user_heartbeat_values"
    assert_route :get, "/api/admin/v1/user/get_users_by_ip", "heartbeats", "get_users_by_ip"
    assert_route :get, "/api/admin/v1/user/get_users_by_machine", "heartbeats", "get_users_by_machine"

    assert_route :post, "/api/admin/v1/user/convict", "permissions", "user_convict"
    assert_route :get, "/api/admin/v1/user/trust_logs", "trust_level_audit_logs", "trust_logs"
  end

  private

  def assert_route(method, path, controller, action)
    route = Rails.application.routes.recognize_path(path, method: method)
    assert_equal({ controller: "api/admin/v1/#{controller}", action: action }, route.slice(:controller, :action))
  end
end
