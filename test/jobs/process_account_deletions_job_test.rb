require "test_helper"

class ProcessAccountDeletionsJobTest < ActiveSupport::TestCase
  class DeletionRepository
    attr_accessor :fail_deletion
    attr_reader :deleted_user_ids

    def initialize
      @deleted_user_ids = []
    end

    def prepare_deletion(user_id)
      HeartbeatDeletion.find_or_create_by!(user_id:)
    end

    def soft_delete_user(user_id, **)
      raise ClickHouse::Client::Error, "temporarily unavailable" if fail_deletion

      deleted_user_ids << user_id
    end
  end

  setup do
    @previous_repository = HeartbeatRepository.instance_variable_get(:@current)
    @previous_test_setting = ENV["CLICKHOUSE_TEST"]
  end

  teardown do
    ENV["CLICKHOUSE_TEST"] = @previous_test_setting
    HeartbeatRepository.instance_variable_set(:@current, @previous_repository)
  end

  test "PostgreSQL account deletion completes after anonymization" do
    ENV["CLICKHOUSE_TEST"] = "0"
    request = ready_request

    ProcessAccountDeletionsJob.perform_now

    assert request.reload.completed?
    assert_nil HeartbeatDeletion.find_by(user_id: request.user_id)
  end

  test "ClickHouse account deletion remains approved until ClickHouse acknowledges it" do
    repository = DeletionRepository.new
    use_clickhouse(repository)
    request = ready_request

    ProcessAccountDeletionsJob.perform_now

    deletion = HeartbeatDeletion.find_by!(user_id: request.user_id)
    assert request.reload.approved?
    assert deletion.pending?

    HeartbeatDeletionJob.new.perform(deletion.id)

    assert request.reload.completed?
    assert deletion.reload.completed?
    assert_equal [ request.user_id ], repository.deleted_user_ids
  end

  test "failed ClickHouse deletion keeps the request active and retry completes it" do
    repository = DeletionRepository.new
    repository.fail_deletion = true
    use_clickhouse(repository)
    request = ready_request

    ProcessAccountDeletionsJob.perform_now
    deletion = HeartbeatDeletion.find_by!(user_id: request.user_id)

    assert_raises(ClickHouse::Client::Error) { HeartbeatDeletionJob.new.perform(deletion.id) }
    assert request.reload.approved?
    assert deletion.reload.failed?

    repository.fail_deletion = false
    HeartbeatDeletionJob.new.perform(deletion.id)

    assert request.reload.completed?
    assert deletion.reload.completed?
  end

  test "completed ClickHouse deletion reconciles an unacknowledged request" do
    repository = DeletionRepository.new
    use_clickhouse(repository)
    request = ready_request
    deletion = HeartbeatDeletion.create!(
      user_id: request.user_id,
      status: :completed,
      completed_at: Time.current
    )

    HeartbeatDeletionJob.new.perform(deletion.id)

    assert request.reload.completed?
    assert_empty repository.deleted_user_ids
  end

  test "pending transfer defers account anonymization before deletion is recorded" do
    use_clickhouse(HeartbeatRepository.new(client: Object.new))
    request = ready_request
    target = User.create!(timezone: "UTC")
    HeartbeatTransfer.create!(
      from_user_id: request.user_id,
      to_user_id: target.id,
      heartbeat_count: 0
    )
    original_username = request.user.username

    ProcessAccountDeletionsJob.perform_now

    assert request.reload.approved?
    assert_equal original_username, request.user.reload.username
    assert_nil HeartbeatDeletion.find_by(user_id: request.user_id)
  end

  private

  def ready_request
    user = User.create!(timezone: "UTC", username: "delete_#{SecureRandom.hex(4)}")
    DeletionRequest.create_for_user!(user).tap do |request|
      request.update!(status: :approved, scheduled_deletion_at: 1.minute.ago)
    end
  end

  def use_clickhouse(repository)
    ENV["CLICKHOUSE_TEST"] = "1"
    HeartbeatRepository.instance_variable_set(:@current, repository)
  end
end
