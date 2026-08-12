require "test_helper"

class SailorsLogPollForChangesJobTest < ActiveSupport::TestCase
  SailorsLogStub = Data.define(:user)

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @previous_setting = ENV["CLICKHOUSE_TEST"]
    @previous_repository = HeartbeatRepository.instance_variable_get(:@current)
  end

  teardown do
    Rails.cache.clear
    Rails.cache = @original_cache
    ENV["CLICKHOUSE_TEST"] = @previous_setting
    HeartbeatRepository.instance_variable_set(:@current, @previous_repository)
  end

  test "ClickHouse all-time project durations retain a short poll cache" do
    user = User.create!(timezone: "UTC")
    ProjectRepoMapping.create!(user:, project_name: "archived", archived_at: Time.current)
    calls = []
    repository = Object.new
    repository.define_singleton_method(:project_durations_by_user) do |user_ids|
      calls << user_ids
      user_ids.to_h { |user_id| [ user_id, { "active" => 3_600, "archived" => 7_200 } ] }
    end
    ENV["CLICKHOUSE_TEST"] = "1"
    HeartbeatRepository.instance_variable_set(:@current, repository)
    job = SailorsLogPollForChangesJob.new
    sailors_logs = [ SailorsLogStub.new(user) ]

    2.times do
      assert_equal({ user.id => { "active" => 3_600 } }, job.send(:project_durations_for, sailors_logs))
    end
    assert_equal [ [ user.id ] ], calls
  end
end
