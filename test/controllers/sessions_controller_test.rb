require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActiveRecord::FixtureSet.reset_cache
  end
  test "hca_new stores continue path for oauth authorize" do
    continue_path = "/oauth/authorize?client_id=Ck47_6hihaBqZO7z3CLmJlCB-0NzHtZHGeDBwG4CqRs&redirect_uri=https%3A%2F%2Fgame.hackclub.com%2Fhackatime%2Fcallback&response_type=code&scope=profile%20read&state=a254695483383bd70ee41424b75d638a869e5d6769e11b50"

    get hca_auth_path(continue: continue_path)

    assert_equal continue_path, session.dig(:return_data, "url")
    assert_response :redirect
  end

  test "hca_new rejects external continue URL" do
    get hca_auth_path(continue: "https://evil.example.com/phish")

    assert_nil session.dig(:return_data, "url")
    assert_response :redirect
  end

  test "hca_new rejects javascript continue URL" do
    get hca_auth_path(continue: "javascript:alert(1)")

    assert_nil session.dig(:return_data, "url")
    assert_response :redirect
  end
end
