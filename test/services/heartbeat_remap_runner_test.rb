require "test_helper"

class HeartbeatRemapRunnerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
    clear_enqueued_jobs
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    Rails.cache.clear
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end

  test "dry runs checkpoint and audit corrections without changing heartbeats or scheduling rollups" do
    heartbeat = legacy_heartbeat(entity: ".env", language: "Ezhil")
    original_hash = heartbeat.fields_hash
    run = HeartbeatRemapRunner.start!(dry_run: true, batch_size: 1)
    clear_enqueued_jobs

    assert_no_enqueued_jobs(only: DashboardRollupRefreshJob) do
      HeartbeatRemapRunner.process_batch!(run)
    end

    assert_predicate run.reload, :completed?
    assert_equal heartbeat.id, run.cursor_id
    assert_equal 1, run.scanned_count
    assert_equal 1, run.changed_count
    assert_equal "Ezhil", heartbeat.reload.language
    assert_equal original_hash, heartbeat.fields_hash
    change = run.remap_changes.sole
    assert_equal "Ezhil", change.preimage.fetch("language")
    assert_equal "Dotenv", change.postimage.fetch("language")
  end

  test "write runs resume in bounded batches and schedule one rollup per affected user" do
    first = legacy_heartbeat(entity: ".env", language: "Ezhil")
    second = legacy_heartbeat(entity: ".gitignore", language: "Text", time: first.time + 1, user: first.user)
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 1)
    clear_enqueued_jobs

    assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ first.user_id ]) do
      HeartbeatRemapRunner.process_batch!(run)
    end

    assert_predicate run.reload, :running?
    assert_equal first.id, run.cursor_id
    assert_equal "Dotenv", first.reload.language
    assert_equal "Text", second.reload.language

    Rails.cache.clear
    clear_enqueued_jobs
    assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ first.user_id ]) do
      HeartbeatRemapRunner.process_batch!(run)
    end

    assert_predicate run.reload, :completed?
    assert_equal "Ignore List", second.reload.language
    assert_equal 2, run.changed_count
  end

  test "rollup scheduling failures do not mark committed batches as failed" do
    heartbeat = legacy_heartbeat(entity: ".env", language: "Ezhil")
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 10)
    original_schedule_for = DashboardRollupRefreshJob.method(:schedule_for)
    DashboardRollupRefreshJob.define_singleton_method(:schedule_for) { |*| raise "queue unavailable" }

    error = assert_raises(RuntimeError) { HeartbeatRemapRunner.process_batch!(run) }
    assert_equal "queue unavailable", error.message

    assert_predicate run.reload, :completed?
    assert_equal heartbeat.id, run.cursor_id
    assert_equal "Dotenv", heartbeat.reload.language
  ensure
    DashboardRollupRefreshJob.define_singleton_method(:schedule_for, original_schedule_for) if original_schedule_for
  end

  test "write runs compare identity fields and soft-delete only proven duplicate collisions" do
    legacy = legacy_heartbeat(entity: ".env", language: "Ezhil")
    canonical = legacy_heartbeat(
      entity: legacy.entity,
      language: "Dotenv",
      time: legacy.time,
      user: legacy.user
    )
    legacy_hash = legacy.fields_hash
    HeartbeatHashAlias.create!(
      user: legacy.user,
      heartbeat_id: canonical.id,
      alias_hash: "pre-existing-client-hash",
      canonical_hash: canonical.fields_hash
    )
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 10)

    HeartbeatRemapRunner.process_batch!(run)

    assert_equal legacy.id, legacy.reload.id
    assert_equal "Dotenv", legacy.language
    assert_nil legacy.deleted_at
    assert_not_nil canonical.reload.deleted_at
    assert_equal 1, run.reload.deduplicated_count
    assert_equal legacy.id, HeartbeatHashAlias.find_by!(user_id: legacy.user_id, alias_hash: legacy_hash).heartbeat_id
    assert_equal legacy.id, HeartbeatHashAlias.find_by!(alias_hash: "pre-existing-client-hash").heartbeat_id
  end

  test "write runs audit hash collisions with unequal identity and leave both rows unchanged" do
    legacy = legacy_heartbeat(entity: ".env", language: "Ezhil")
    canonical_hash = Heartbeat.generate_fields_hash(legacy.attributes.merge("language" => "Dotenv"))
    unrelated = legacy_heartbeat(entity: "unrelated.rb", language: "Ruby", time: legacy.time + 1)
    unrelated.update_column(:fields_hash, canonical_hash)
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 10)

    HeartbeatRemapRunner.process_batch!(run)

    assert_equal "Ezhil", legacy.reload.language
    assert_nil unrelated.reload.deleted_at
    assert_equal 1, run.reload.unsafe_count
    assert_predicate run.remap_changes.find_by!(heartbeat_id: legacy.id), :action_unsafe_collision?
  end

  test "rollback restores corrected rows and soft-deleted collision losers from audit preimages" do
    legacy = legacy_heartbeat(entity: ".env", language: "Ezhil")
    canonical = legacy_heartbeat(
      entity: legacy.entity,
      language: "Dotenv",
      time: legacy.time,
      user: legacy.user
    )
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 1)
    HeartbeatRemapRunner.process_batch!(run) until run.reload.completed?
    Rails.cache.clear
    clear_enqueued_jobs

    HeartbeatRemapRunner.start_rollback!(run)
    assert_enqueued_with(job: DashboardRollupRefreshJob, args: [ legacy.user_id ]) do
      HeartbeatRemapRunner.rollback_batch!(run)
    end

    assert_predicate run.reload, :rolling_back?
    assert_equal "Ezhil", legacy.reload.language
    assert_nil legacy.deleted_at
    assert_not_nil canonical.reload.deleted_at

    HeartbeatRemapRunner.rollback_batch!(run)

    assert_predicate run.reload, :rolled_back?
    assert_nil canonical.reload.deleted_at
    assert run.remap_changes.all? { |change| change.rolled_back_at.present? }
  end

  test "rollback restores redirected aliases and removes aliases created by the remap" do
    legacy = legacy_heartbeat(entity: ".env", language: "Ezhil")
    canonical = legacy_heartbeat(
      entity: legacy.entity,
      language: "Dotenv",
      time: legacy.time,
      user: legacy.user
    )
    legacy_hash = legacy.fields_hash
    canonical_hash = canonical.fields_hash
    winner_alias = HeartbeatHashAlias.create!(
      user: legacy.user,
      heartbeat_id: legacy.id,
      alias_hash: "winner-client-hash",
      canonical_hash: legacy_hash
    )
    loser_alias = HeartbeatHashAlias.create!(
      user: legacy.user,
      heartbeat_id: canonical.id,
      alias_hash: "loser-client-hash",
      canonical_hash:
    )
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 1)

    HeartbeatRemapRunner.process_batch!(run) until run.reload.completed?

    assert_equal [ legacy.id, canonical_hash ], winner_alias.reload.values_at(:heartbeat_id, :canonical_hash)
    assert_equal [ legacy.id, canonical_hash ], loser_alias.reload.values_at(:heartbeat_id, :canonical_hash)
    assert HeartbeatHashAlias.exists?(user_id: legacy.user_id, alias_hash: legacy_hash)
    alias_audits = run.remap_alias_changes.index_by(&:alias_hash)
    assert_equal [ legacy.id, legacy_hash ], alias_audits.fetch("winner-client-hash")
      .values_at(:before_heartbeat_id, :before_canonical_hash)
    assert_equal [ canonical.id, canonical_hash ], alias_audits.fetch("loser-client-hash")
      .values_at(:before_heartbeat_id, :before_canonical_hash)
    assert_nil alias_audits.fetch(legacy_hash).before_heartbeat_id

    HeartbeatRemapRunner.start_rollback!(run)
    HeartbeatRemapRunner.rollback_batch!(run) until run.reload.rolled_back?

    assert_equal [ legacy.id, legacy_hash ], winner_alias.reload.values_at(:heartbeat_id, :canonical_hash)
    assert_equal [ canonical.id, canonical_hash ], loser_alias.reload.values_at(:heartbeat_id, :canonical_hash)
    assert_not HeartbeatHashAlias.exists?(user_id: legacy.user_id, alias_hash: legacy_hash)
  end

  test "repeated alias transitions retain the original preimage and latest postimage" do
    user = create(:user)
    original = legacy_heartbeat(entity: "original.rb", language: "Ruby", user:)
    intermediate = legacy_heartbeat(entity: "intermediate.rb", language: "Ruby", user:)
    final = legacy_heartbeat(entity: "final.rb", language: "Ruby", user:)
    alias_record = HeartbeatHashAlias.create!(
      user:,
      heartbeat_id: original.id,
      alias_hash: "reused-alias",
      canonical_hash: original.fields_hash
    )
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 1)
    first_change = {
      user_id: user.id,
      heartbeat_id: original.id,
      alias_hash: alias_record.alias_hash,
      before_heartbeat_id: original.id,
      before_canonical_hash: original.fields_hash,
      after_heartbeat_id: intermediate.id,
      after_canonical_hash: intermediate.fields_hash
    }
    second_change = first_change.merge(
      before_heartbeat_id: intermediate.id,
      before_canonical_hash: intermediate.fields_hash,
      after_heartbeat_id: final.id,
      after_canonical_hash: final.fields_hash
    )

    HeartbeatRemapRunner.send(:persist_alias_changes, run, [ first_change ])
    HeartbeatRemapRunner.send(:apply_alias_changes, [ first_change ])
    HeartbeatRemapRunner.send(:persist_alias_changes, run, [ second_change ])
    HeartbeatRemapRunner.send(:apply_alias_changes, [ second_change ])

    audit = run.remap_alias_changes.sole
    assert_equal [ original.id, original.fields_hash ],
      audit.values_at(:before_heartbeat_id, :before_canonical_hash)
    assert_equal [ final.id, final.fields_hash ],
      audit.values_at(:after_heartbeat_id, :after_canonical_hash)
    assert_equal [ final.id, final.fields_hash ],
      alias_record.reload.values_at(:heartbeat_id, :canonical_hash)

    stale_count = HeartbeatRemapRunner.send(
      :rollback_alias_changes,
      [ audit ],
      restored_heartbeat_ids: [ original.id ]
    )
    assert_equal 0, stale_count
    assert_equal [ original.id, original.fields_hash ],
      alias_record.reload.values_at(:heartbeat_id, :canonical_hash)
  end

  test "write runs update a batch with a constant number of heartbeat statements" do
    user = create(:user)
    5.times do |offset|
      legacy_heartbeat(entity: ".env", language: "Ezhil", time: Time.current.to_f + offset, user:)
    end
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 10)
    statements = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      statements << payload[:sql] unless payload[:cached]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      HeartbeatRemapRunner.process_batch!(run)
    end

    bulk_updates = statements.grep(/UPDATE heartbeats SET language/i)
    alias_statements = statements.grep(/(?:SELECT|INSERT|UPDATE|DELETE).*heartbeat_hash_aliases/i)
    assert_equal 1, bulk_updates.length
    assert_operator alias_statements.length, :<=, 2
    assert_equal 5, user.heartbeats.where(language: "Dotenv").count
  end

  test "rollback audits stale rows and leaves concurrent changes untouched" do
    heartbeat = legacy_heartbeat(entity: ".env", language: "Ezhil")
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 10)
    HeartbeatRemapRunner.process_batch!(run)
    heartbeat.reload.update!(language: "Concurrent change")

    HeartbeatRemapRunner.start_rollback!(run)
    HeartbeatRemapRunner.rollback_batch!(run)

    assert_equal "Concurrent change", heartbeat.reload.language
    assert_equal 1, run.reload.stale_count
    assert_predicate run, :rolled_back?
  end

  test "rollback does not reactivate a concurrently deleted heartbeat" do
    heartbeat = legacy_heartbeat(entity: ".env", language: "Ezhil")
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 10)
    HeartbeatRemapRunner.process_batch!(run)
    heartbeat.soft_delete

    HeartbeatRemapRunner.start_rollback!(run)
    HeartbeatRemapRunner.rollback_batch!(run)

    assert_not_nil heartbeat.reload.deleted_at
    assert_equal 1, run.reload.stale_count
    assert_predicate run, :rolled_back?
  end

  test "rollback preserves concurrently redirected aliases and counts them as stale" do
    heartbeat = legacy_heartbeat(entity: ".env", language: "Ezhil")
    other = legacy_heartbeat(entity: "main.rb", language: "Ruby", user: heartbeat.user)
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 1)
    HeartbeatRemapRunner.process_batch!(run) until run.reload.completed?
    alias_record = HeartbeatHashAlias.find_by!(heartbeat_id: heartbeat.id)
    alias_record.update!(heartbeat_id: other.id, canonical_hash: other.fields_hash)

    HeartbeatRemapRunner.start_rollback!(run)
    HeartbeatRemapRunner.rollback_batch!(run) until run.reload.rolled_back?

    assert_equal "Ezhil", heartbeat.reload.language
    assert_equal [ other.id, other.fields_hash ], alias_record.reload.values_at(:heartbeat_id, :canonical_hash)
    assert_equal 1, run.reload.stale_count
    assert_not_nil run.remap_alias_changes.sole.rolled_back_at
  end

  test "final rollup recovery uses bounded batches and schedules each affected user once" do
    user = create(:user)
    3.times do |offset|
      legacy_heartbeat(entity: "config.cjs", language: "Ezhil", user:, time: Time.current.to_f + offset)
    end
    run = HeartbeatRemapRunner.start!(dry_run: false, batch_size: 1)
    HeartbeatRemapRunner.process_batch!(run) until run.reload.completed?
    assert_equal [ "JavaScript" ], user.heartbeats.distinct.pluck(:language)
    Rails.cache.clear
    clear_enqueued_jobs
    statements = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      statements << payload[:sql] if payload[:sql].match?(/SELECT.*heartbeat_remap_changes/i)
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      assert_enqueued_jobs 1, only: DashboardRollupRefreshJob do
        HeartbeatRemapRunner.schedule_rollups!(run)
      end
    end

    assert_not_empty statements
    assert statements.all? { |sql| sql.include?("LIMIT") }, statements.join("\n")
  end

  private

  def legacy_heartbeat(entity:, language:, time: Time.current.to_f, user: create(:user))
    create(:heartbeat,
      user:,
      entity:,
      language:,
      time:,
      type: "file",
      category: "coding",
      dependencies: [],
      is_write: false,
      source_type: :direct_entry)
  end
end
