require "test_helper"

class HeartbeatRemapJobTest < ActiveJob::TestCase
  test "continuable job processes all database-backed batches" do
    user = create(:user)
    2.times do |offset|
      create(:heartbeat,
        user:,
        entity: ".env",
        language: "Ezhil",
        category: "coding",
        type: "file",
        time: Time.current.to_f + offset)
    end
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 1)

    HeartbeatRemapJob.perform_now(run.id)

    assert_predicate run.reload, :completed?
    assert_equal 2, run.scanned_count
    assert_equal [ "Dotenv" ], user.heartbeats.distinct.pluck(:language)
  end
end
