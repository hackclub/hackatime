require "test_helper"

class AccountMergeServiceTest < ActiveSupport::TestCase
  test "renames transferred api keys when the older account already has the same key name" do
    older = create(:user, username: "older_user")
    newer = create(:user, username: "newer_user")
    create(:api_key, user: older, name: "Wakatime API Key")
    transferred_key = create(:api_key, user: newer, name: "Wakatime API Key")

    result = AccountMergeService.call(older_user: older, newer_user: newer)

    assert_match(/\A0 heartbeats moved, 1 API keys transferred, 0 goals transferred, 0 sessions\/tokens revoked, \d+ related records cleaned up, user ##{newer.id} deleted\z/, result)
    assert_nil User.find_by(id: newer.id)
    assert_equal older.id, transferred_key.reload.user_id
    assert_equal "Wakatime API Key (transferred)", transferred_key.name
    assert_equal [ "Wakatime API Key", "Wakatime API Key (transferred)" ], older.api_keys.order(:name).pluck(:name)
  end

  test "transfers the newer instance import source when the older account does not have one" do
    older = create(:user, username: "older_user")
    newer = create(:user, username: "newer_user")
    create_instance_import_source_for(newer, endpoint_url: "https://newer.example.com")

    AccountMergeService.call(older_user: older, newer_user: newer)

    assert_nil User.find_by(id: newer.id)
    assert_equal 1, instance_import_source_count_for(older)
    assert_equal 0, instance_import_source_count_for(newer)
    assert_equal "https://newer.example.com", instance_import_source_endpoint_for(older)
  end

  test "removes the newer instance import source when the older account already has one" do
    older = create(:user, username: "older_user")
    newer = create(:user, username: "newer_user")
    create_instance_import_source_for(older, endpoint_url: "https://older.example.com")
    create_instance_import_source_for(newer, endpoint_url: "https://newer.example.com")

    AccountMergeService.call(older_user: older, newer_user: newer)

    assert_nil User.find_by(id: newer.id)
    assert_equal 1, instance_import_source_count_for(older)
    assert_equal 0, instance_import_source_count_for(newer)
    assert_equal "https://older.example.com", instance_import_source_endpoint_for(older)
  end

  test "rolls back earlier changes when a later write fails" do
    older = create(:user, username: "older_user")
    newer = create(:user, username: "newer_user")
    heartbeat = create(:heartbeat, user: newer)
    create(:api_key, user: older, name: "Wakatime API Key")
    transferred_key = create(:api_key, user: newer, name: "Wakatime API Key")
    create(:goal, user: older)
    create(:goal, user: newer)

    error = assert_raises(AccountMergeService::MergeError) do
      AccountMergeService.call(older_user: older, newer_user: newer)
    end

    assert_equal "Destination account has conflicting records", error.message
    assert_instance_of ActiveRecord::RecordNotUnique, error.cause
    assert_equal newer.id, heartbeat.reload.user_id
    assert_equal newer.id, transferred_key.reload.user_id
    assert_equal "Wakatime API Key", transferred_key.name
    assert User.exists?(newer.id)
    assert_equal 1, Goal.where(user_id: older.id).count
    assert_equal 1, Goal.where(user_id: newer.id).count
  end

  private

  def create_instance_import_source_for(user, endpoint_url:)
    create(:instance_import_source,
      user: user,
      endpoint_url: endpoint_url,
      encrypted_api_key: "encrypted-api-key"
    )
  end

  def instance_import_source_count_for(user)
    InstanceImportSource.where(user_id: user.id).count
  end

  def instance_import_source_endpoint_for(user)
    InstanceImportSource.find_by(user_id: user.id)&.endpoint_url
  end
end
