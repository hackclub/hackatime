require "test_helper"

class Cache::ActivityJobTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  # A real cache with a controllable publication boundary, not a mocked job or
  # database. Both tests execute CurrentlyHackingJob's real calculation.
  class PausingStore < ActiveSupport::Cache::MemoryStore
    attr_accessor :pause_on
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

  test "a cache calculation started during erasure waits and publishes only post-commit data" do
    @cache.pause_on = :clear
    eraser = in_connection { Privacy::Eraser.new(@claims).call(action: "delete") }
    Timeout.timeout(10) { @cache.reached.pop }
    started = Queue.new
    writer = in_connection do
      started << ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
      Cache::CurrentlyHackingJob.perform_now(force_reload: true)
    end
    pid = Timeout.timeout(10) { started.pop }
    # Release erasure once the calculation either waits at the database barrier
    # or finishes. Without the barrier it finishes with the uncommitted user.
    Timeout.timeout(10) do
      while writer.alive? && ActiveRecord::Base.connection.select_value("SELECT wait_event FROM pg_stat_activity WHERE pid = #{Integer(pid)}") != "advisory"
        sleep 0.01
      end
    end
    @cache.resume << true
    Timeout.timeout(10) { eraser.value }
    result = Timeout.timeout(10) { writer.value }

    assert_not User.exists?(@user.id)
    assert_not_includes result[:users].map(&:id), @user.id
    assert_not_includes @cache.read("cache/currently_hacking_job")[:users].map(&:id), @user.id
  end

  private

  def in_connection(&block)
    Thread.new { ActiveRecord::Base.connection_pool.with_connection(&block) }.tap { |worker| @workers << worker }
  end
end
