require "test_helper"

class My::HeartbeatImportsControllerTest < ActionDispatch::IntegrationTest
  test "create rejects guests" do
    post my_heartbeat_imports_path

    assert_response :unauthorized
    assert_equal "You must be logged in to view this page.", JSON.parse(response.body)["error"]
  end

  test "create rejects non-development environment" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)

    post my_heartbeat_imports_path

    assert_response :forbidden
    assert_equal "Heartbeat import is only available in development.", JSON.parse(response.body)["error"]
  end

  test "show rejects non-development environment" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)

    get my_heartbeat_import_path("import-123")

    assert_response :forbidden
    assert_equal "Heartbeat import is only available in development.", JSON.parse(response.body)["error"]
  end

  test "create returns error when file is missing" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)

    with_development_env do
      post my_heartbeat_imports_path
    end

    assert_response :unprocessable_entity
    assert_equal "pls select a file to import", JSON.parse(response.body)["error"]
  end

  test "create returns error when file type is invalid" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)

    with_development_env do
      post my_heartbeat_imports_path, params: {
        heartbeat_file: uploaded_file(filename: "heartbeats.txt", content_type: "text/plain", content: "hello")
      }
    end

    assert_response :unprocessable_entity
    assert_equal "pls upload only json (download from the button above it)", JSON.parse(response.body)["error"]
  end

  test "create starts import and returns status" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)
    expected_status = { "state" => "queued", "progress_percent" => 0 }

    with_development_env do
      with_runner_stubs(start_return: "import-123", status_return: expected_status) do
          post my_heartbeat_imports_path, params: {
            heartbeat_file: uploaded_file
          }
      end
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal "import-123", body["import_id"]
    assert_equal "queued", body.dig("status", "state")
  end

  private

  def sign_in_as(user)
    token = user.sign_in_tokens.create!(auth_type: :email)
    get auth_token_path(token: token.token)
    assert_equal user.id, session[:user_id]
  end

  def with_development_env
    rails_singleton = class << Rails; self; end
    rails_singleton.alias_method :__original_env_for_test, :env
    rails_singleton.define_method(:env) { ActiveSupport::StringInquirer.new("development") }
    yield
  ensure
    rails_singleton.remove_method :env
    rails_singleton.alias_method :env, :__original_env_for_test
    rails_singleton.remove_method :__original_env_for_test
  end

  def with_runner_stubs(start_return:, status_return:)
    runner_singleton = class << HeartbeatImportRunner; self; end
    runner_singleton.alias_method :__original_start_for_test, :start
    runner_singleton.alias_method :__original_status_for_test, :status
    runner_singleton.define_method(:start) { |**| start_return }
    runner_singleton.define_method(:status) { |**| status_return }
    yield
  ensure
    runner_singleton.remove_method :start
    runner_singleton.remove_method :status
    runner_singleton.alias_method :start, :__original_start_for_test
    runner_singleton.alias_method :status, :__original_status_for_test
    runner_singleton.remove_method :__original_start_for_test
    runner_singleton.remove_method :__original_status_for_test
  end

  def uploaded_file(filename: "heartbeats.json", content_type: "application/json", content: '{"heartbeats":[]}')
    Rack::Test::UploadedFile.new(
      StringIO.new(content),
      content_type,
      original_filename: filename
    )
  end
end
