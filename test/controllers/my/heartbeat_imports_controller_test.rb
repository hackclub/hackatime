require "test_helper"

class My::HeartbeatImportsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  test "create rejects guests" do
    post my_heartbeat_imports_path

    assert_response :unauthorized
    assert_equal "You must be logged in to view this page.", JSON.parse(response.body)["error"]
  end

  test "create rejects non-development environment" do
    user = users(:one)
    sign_in_as(user)

    post my_heartbeat_imports_path

    assert_response :forbidden
    assert_equal "Heartbeat import is only available in development.", JSON.parse(response.body)["error"]
  end

  test "show rejects non-development environment" do
    user = users(:one)
    sign_in_as(user)

    get my_heartbeat_import_path("import-123")

    assert_response :forbidden
    assert_equal "Heartbeat import is only available in development.", JSON.parse(response.body)["error"]
  end

  test "create returns error when file is missing" do
    user = users(:one)
    sign_in_as(user)

    with_development_env do
      post my_heartbeat_imports_path
    end

    assert_response :unprocessable_entity
    assert_equal "pls select a file to import", JSON.parse(response.body)["error"]
  end

  test "create returns error when file type is invalid" do
    user = users(:one)
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
    user = users(:one)
    sign_in_as(user)

    with_development_env do
      with_memory_cache do
        post my_heartbeat_imports_path, params: {
          heartbeat_file: uploaded_file
        }
      end
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert body["import_id"].present?
    assert_equal "queued", body.dig("status", "state")
    assert_equal 0, body.dig("status", "progress_percent")
  end

  test "show returns status for existing import" do
    user = users(:one)
    sign_in_as(user)

    with_development_env do
      with_memory_cache do
        post my_heartbeat_imports_path, params: { heartbeat_file: uploaded_file }
        import_id = JSON.parse(response.body).fetch("import_id")

        get my_heartbeat_import_path(import_id)
      end
    end

    assert_response :success
    assert_equal "queued", JSON.parse(response.body).fetch("state")
  end

  test "show returns not found for unknown import id" do
    user = users(:one)
    sign_in_as(user)

    with_development_env do
      with_memory_cache do
        get my_heartbeat_import_path("missing-import")
      end
    end

    assert_response :not_found
    assert_equal "Import not found", JSON.parse(response.body).fetch("error")
  end

  private

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

  def with_memory_cache
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original_cache
  end

  def uploaded_file(filename: "heartbeats.json", content_type: "application/json", content: '{"heartbeats":[]}')
    Rack::Test::UploadedFile.new(
      StringIO.new(content),
      content_type,
      original_filename: filename
    )
  end
end
