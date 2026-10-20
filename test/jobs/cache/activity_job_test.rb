require "test_helper"

class Cache::ActivityJobTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  # A real cache with a controllable publication boundary, not a mocked job or
  # database. Calculations use CurrentlyHackingJob's real queries.
  class PausingStore < ActiveSupport::Cache::MemoryStore
    attr_accessor :pause_on, :clear_queries
    attr_reader :reached, :resume

    def initialize
      super
      @reached, @resume = Queue.new, Queue.new
    end

    def write(name, ...)
      pause(:write) if name == "cache/currently_hacking_job"
      super
    end

    def clear(...)
      result = super
      clear_queries&.times { ActiveRecord::Base.connection.execute("SELECT pg_sleep(1.2)") }
      pause(:clear)
      result
    end

    private

    def pause(operation)
      return unless pause_on == operation
      self.pause_on = nil
      reached << true
      resume.pop
    end
  end

  setup do
    @original_cache, @original_adapter = Rails.cache, ActiveJob::Base.queue_adapter
    @cache = Rails.cache = PausingStore.new
    ActiveJob::Base.queue_adapter = :test
    @workers = []
    @user = create(:user, slack_uid: "U_PRIVACY_CACHE_#{SecureRandom.hex(4)}", display_name_override: "Private cached name")
    create(:heartbeat, user: @user, time: 1.minute.ago.to_f, source_type: :direct_entry, category: "coding")
    @claims = { "request_id" => SecureRandom.uuid, "dry_run" => false,
      "subject" => { "emails" => [], "slack_id" => @user.slack_uid } }
  end

  teardown do
    @cache.resume << true
    @workers.each { |worker| worker.join(10) }
    Privacy::Eraser.new(@claims).call(action: "delete") if User.exists?(@user.id)
    Rails.cache, ActiveJob::Base.queue_adapter = @original_cache, @original_adapter
  end

  test "an in-flight synchronous cache publication prevents erasure until it finishes" do
    @cache.pause_on = :write
    writer = in_connection { Cache::CurrentlyHackingJob.perform_now(force_reload: true) }
    Timeout.timeout(10) { @cache.reached.pop }

    error = assert_raises(Privacy::Error) { Privacy::Eraser.new(@claims).call(action: "delete") }
    assert_equal "work_in_progress", error.message
    assert User.exists?(@user.id)
    @cache.resume << true
    assert_includes Timeout.timeout(10) { writer.value }[:users].map(&:id), @user.id

    Privacy::Eraser.new(@claims).call(action: "delete")
    assert_not User.exists?(@user.id)
    assert_nil @cache.read("cache/currently_hacking_job")
    assert_not_includes Cache::CurrentlyHackingJob.perform_now[:users].map(&:id), @user.id
  end

  test "cache reads during erasure finish without publishing a pre-commit snapshot" do
    @cache.pause_on = :clear
    eraser = in_connection { Privacy::Eraser.new(@claims).call(action: "delete") }
    Timeout.timeout(10) { @cache.reached.pop }
    # Exercise ordinary reads and forced reloads while deletion is still paused.
    [ false, true ].each do |force_reload|
      writer = in_connection { Cache::CurrentlyHackingJob.perform_now(force_reload:) }
      result = Timeout.timeout(1) { writer.value }
      assert_includes result[:users].map(&:id), @user.id
      assert_nil @cache.read("cache/currently_hacking_job")
    end
    @cache.resume << true
    Timeout.timeout(10) { eraser.value }

    assert_not User.exists?(@user.id)
    result = Cache::CurrentlyHackingJob.perform_now
    assert_not_includes result[:users].map(&:id), @user.id
    assert_not_includes @cache.read("cache/currently_hacking_job")[:users].map(&:id), @user.id
  end

  test "a stalled storage operation releases job locks at the deadline before it resumes" do
    @cache.pause_on = :clear
    eraser = in_connection do
      Privacy::Eraser.new(@claims).call(action: "delete")
    rescue Privacy::Error => error
      error
    end
    Timeout.timeout(10) { @cache.reached.pop }
    enqueue = in_connection do
      GoodJob::Job.create!(job_class: "UnrelatedJob", active_job_id: SecureRandom.uuid, serialized_params: {})
    end
    # The storage operation remains paused. PostgreSQL must release the locks
    # independently, not just check elapsed time once storage eventually returns.
    job = Timeout.timeout(4) { enqueue.value }
    assert User.exists?(@user.id)
    assert Heartbeat.with_deleted.with_excluded.exists?(user_id: @user.id)
    assert GoodJob::Job.exists?(job.id)

    @cache.resume << true
    error = Timeout.timeout(10) { eraser.value }
    assert_equal "manual_review_required", error.message
    assert_equal 409, error.status
    assert User.exists?(@user.id)
  ensure
    job&.delete
  end

  test "the deletion deadline spans multiple individually short statements and rolls back" do
    @cache.clear_queries = 2
    error = assert_raises(Privacy::Error) { Privacy::Eraser.new(@claims).call(action: "delete") }
    assert_equal "manual_review_required", error.message
    assert_equal 409, error.status
    assert User.exists?(@user.id)
    assert Heartbeat.with_deleted.with_excluded.exists?(user_id: @user.id)
  ensure
    @cache.clear_queries = nil
  end

  private

  def in_connection(&block)
    Thread.new { ActiveRecord::Base.connection_pool.with_connection(&block) }.tap { |worker| @workers << worker }
  end
end
