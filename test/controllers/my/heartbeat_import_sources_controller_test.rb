require "test_helper"

class My::HeartbeatImportSourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Flipper.enable(:wakatime_imports)
  end

  teardown do
    Flipper.disable(:wakatime_imports)
  end

  test "requires auth for create" do
    post my_heartbeat_import_source_path, params: {
      heartbeat_import_source: {
        endpoint_url: "https://wakatime.com/api/v1",
        encrypted_api_key: "waka_00000000-0000-0000-0000-000000000001"
      }
    }

    assert_response :redirect
    assert_redirected_to root_path
  end

  test "authenticated user can create source and queue sync" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)
    GoodJob::Job.where(job_class: "HeartbeatImportSourceSyncJob").delete_all

    assert_difference -> { HeartbeatImportSource.count }, 1 do
      assert_difference -> { GoodJob::Job.where(job_class: "HeartbeatImportSourceSyncJob").count }, 1 do
        post my_heartbeat_import_source_path, params: {
          heartbeat_import_source: {
            endpoint_url: "https://wakatime.com/api/v1",
            encrypted_api_key: "waka_00000000-0000-0000-0000-000000000001",
            sync_enabled: "1"
          }
        }
      end
    end

    assert_response :redirect
    assert_redirected_to my_settings_data_path
  end

  test "show returns configured source payload" do
    user = User.create!(timezone: "UTC")
    source = user.create_heartbeat_import_source!(
      provider: :wakatime_compatible,
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "waka_00000000-0000-0000-0000-000000000001"
    )
    sign_in_as(user)

    get my_heartbeat_import_source_path

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal source.id, payload.dig("import_source", "id")
    assert_equal "wakatime_compatible", payload.dig("import_source", "provider")
  end

  test "sync now queues source sync" do
    user = User.create!(timezone: "UTC")
    source = user.create_heartbeat_import_source!(
      provider: :wakatime_compatible,
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "waka_00000000-0000-0000-0000-000000000001",
      sync_enabled: true
    )
    sign_in_as(user)
    GoodJob::Job.where(job_class: "HeartbeatImportSourceSyncJob").delete_all

    assert_difference -> { GoodJob::Job.where(job_class: "HeartbeatImportSourceSyncJob").count }, 1 do
      post sync_my_heartbeat_import_source_path
    end

    assert_response :redirect
    assert_redirected_to my_settings_data_path
    assert_equal source.id, GoodJob::Job.where(job_class: "HeartbeatImportSourceSyncJob").last.serialized_params.dig("arguments", 0)
  end

  test "destroy removes source" do
    user = User.create!(timezone: "UTC")
    user.create_heartbeat_import_source!(
      provider: :wakatime_compatible,
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "waka_00000000-0000-0000-0000-000000000001"
    )
    sign_in_as(user)

    assert_difference -> { HeartbeatImportSource.count }, -1 do
      delete my_heartbeat_import_source_path
    end

    assert_response :redirect
    assert_redirected_to my_settings_data_path
  end

  test "returns not found json when imports are disabled" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)
    Flipper.disable(:wakatime_imports)

    get my_heartbeat_import_source_path, as: :json

    assert_response :not_found
    payload = JSON.parse(response.body)
    assert_equal "Imports are currently disabled.", payload["error"]
  end
end
