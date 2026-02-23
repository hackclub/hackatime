require "test_helper"
require "webmock/minitest"
require "socket"
require "net/http"
require "timeout"

class WakatimeMirrorSyncJobTest < ActiveJob::TestCase
  setup do
    Flipper.enable(:wakatime_imports_mirrors)
  end

  teardown do
    Flipper.disable(:wakatime_imports_mirrors)
  end

  class MockWakatimeServer
    attr_reader :base_url, :port

    def initialize
      @requests = Queue.new
      @server = TCPServer.new("0.0.0.0", 0)
      @stopped = false
      @clients = []
      @mutex = Mutex.new
      @port = @server.addr[1]
      @base_url = "http://127.0.0.2:#{@port}/api/v1"
    end

    def start
      @thread = Thread.new do
        loop do
          break if @stopped

          socket = @server.accept
          @mutex.synchronize { @clients << socket }
          handle_client(socket)
        rescue IOError, Errno::EBADF
          break
        end
      end
      wait_until_ready!
    end

    def stop
      @stopped = true
      @server.close unless @server.closed?
      @mutex.synchronize do
        @clients.each { |client| client.close unless client.closed? }
        @clients.clear
      end
      @thread&.join(2)
    end

    def pop_requests
      requests = []
      loop do
        requests << @requests.pop(true)
      end
    rescue ThreadError
      requests
    end

    private

    def handle_client(socket)
      request_line = socket.gets
      return if request_line.nil?

      _method, path, = request_line.split(" ")
      headers = {}
      while (line = socket.gets)
        break if line == "\r\n"

        key, value = line.split(":", 2)
        headers[key.to_s.strip.downcase] = value.to_s.strip
      end

      content_length = headers.fetch("content-length", "0").to_i
      body = content_length.positive? ? socket.read(content_length).to_s : ""

      if path == "/api/v1/users/current/heartbeats.bulk"
        @requests << {
          path: path,
          body: body,
          authorization: headers["authorization"]
        }
        respond(socket, 201, "{}")
      elsif path == "/__health"
        respond(socket, 200, "{}")
      else
        respond(socket, 404, "{}")
      end
    ensure
      @mutex.synchronize { @clients.delete(socket) }
      socket.close unless socket.closed?
    end

    def respond(socket, status, body)
      phrase = status == 200 ? "OK" : status == 201 ? "Created" : "Not Found"
      socket.write("HTTP/1.1 #{status} #{phrase}\r\n")
      socket.write("Content-Type: application/json\r\n")
      socket.write("Content-Length: #{body.bytesize}\r\n")
      socket.write("Connection: close\r\n")
      socket.write("\r\n")
      socket.write(body)
    end

    def wait_until_ready!
      Timeout.timeout(5) do
        loop do
          begin
            response = Net::HTTP.get_response(URI("http://127.0.0.2:#{@port}/__health"))
            return if response.is_a?(Net::HTTPSuccess)
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          end
          sleep 0.05
        end
      end
    end
  end

  def create_heartbeat(user:, source_type:, entity:, project: "mirror-project", at_time: Time.current)
    user.heartbeats.create!(
      entity: entity,
      type: "file",
      category: "coding",
      time: at_time.to_f,
      project: project,
      source_type: source_type
    )
  end

  test "sync sends only direct heartbeats in chunks of 25 and advances cursor" do
    user = User.create!(timezone: "UTC")
    mirror = user.wakatime_mirrors.create!(
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "mirror-key"
    )

    direct_heartbeats = 30.times.map do |index|
      create_heartbeat(
        user: user,
        source_type: :direct_entry,
        entity: "src/direct_#{index}.rb",
        project: "direct-project",
        at_time: Time.current + index.seconds
      )
    end

    5.times do |index|
      create_heartbeat(
        user: user,
        source_type: :wakapi_import,
        entity: "src/imported_#{index}.rb",
        project: "import-project",
        at_time: Time.current + (100 + index).seconds
      )
    end

    payload_batches = []
    stub_request(:post, "https://wakatime.com/api/v1/users/current/heartbeats.bulk")
      .to_return do |request|
        payload_batches << JSON.parse(request.body)
        { status: 201, body: "{}", headers: { "Content-Type" => "application/json" } }
      end

    with_development_env do
      WakatimeMirrorSyncJob.perform_now(mirror.id)
    end

    assert_equal [ 25, 5 ], payload_batches.map(&:size)
    assert_equal 30, payload_batches.flatten.size
    assert payload_batches.flatten.all? { |row| row["project"] == "direct-project" }
    assert_equal direct_heartbeats.last.id, mirror.reload.last_synced_heartbeat_id
  end

  test "sync respects last_synced_heartbeat_id cursor" do
    user = User.create!(timezone: "UTC")
    mirror = user.wakatime_mirrors.create!(
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "mirror-key"
    )

    first = create_heartbeat(
      user: user,
      source_type: :direct_entry,
      entity: "src/old.rb",
      at_time: Time.current - 1.minute
    )
    create_heartbeat(
      user: user,
      source_type: :direct_entry,
      entity: "src/new.rb",
      at_time: Time.current
    )
    mirror.update!(last_synced_heartbeat_id: first.id)

    payload_batches = []
    stub_request(:post, "https://wakatime.com/api/v1/users/current/heartbeats.bulk")
      .to_return do |request|
        payload_batches << JSON.parse(request.body)
        { status: 201, body: "{}", headers: { "Content-Type" => "application/json" } }
      end

    WakatimeMirrorSyncJob.perform_now(mirror.id)

    assert_equal 1, payload_batches.flatten.size
    assert_equal "src/new.rb", payload_batches.flatten.first["entity"]
  end

  test "auth failures disable mirror and stop syncing" do
    user = User.create!(timezone: "UTC")
    mirror = user.wakatime_mirrors.create!(
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "mirror-key"
    )
    create_heartbeat(
      user: user,
      source_type: :direct_entry,
      entity: "src/direct.rb"
    )

    stub_request(:post, "https://wakatime.com/api/v1/users/current/heartbeats.bulk")
      .to_return(status: 401, body: "{}")

    with_development_env do
      WakatimeMirrorSyncJob.perform_now(mirror.id)
    end

    mirror.reload
    assert_not mirror.enabled
    assert_includes mirror.last_error_message, "Authentication failed"
    assert mirror.last_error_at.present?
    assert_equal 1, mirror.consecutive_failures
  end

  test "transient failures keep mirror enabled and raise for retry" do
    user = User.create!(timezone: "UTC")
    mirror = user.wakatime_mirrors.create!(
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "mirror-key"
    )
    create_heartbeat(
      user: user,
      source_type: :direct_entry,
      entity: "src/direct.rb"
    )

    stub_request(:post, "https://wakatime.com/api/v1/users/current/heartbeats.bulk")
      .to_return(status: 500, body: "{}")

    assert_raises(WakatimeMirrorSyncJob::MirrorTransientError) do
      WakatimeMirrorSyncJob.new.perform(mirror.id)
    end

    mirror.reload
    assert mirror.enabled
    assert_equal 1, mirror.consecutive_failures
  end

  test "sync posts to a real wakatime-compatible mock server on a random port" do
    WebMock.allow_net_connect!
    server = MockWakatimeServer.new
    server.start

    user = User.create!(timezone: "UTC")
    mirror = user.wakatime_mirrors.create!(
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "mirror-key"
    )
    mirror.update_column(:endpoint_url, server.base_url)

    create_heartbeat(
      user: user,
      source_type: :direct_entry,
      entity: "src/direct_1.rb",
      project: "direct-project"
    )
    create_heartbeat(
      user: user,
      source_type: :direct_entry,
      entity: "src/direct_2.rb",
      project: "direct-project"
    )
    create_heartbeat(
      user: user,
      source_type: :wakapi_import,
      entity: "src/imported.rb",
      project: "import-project"
    )

    WakatimeMirrorSyncJob.perform_now(mirror.id)

    requests = server.pop_requests
    assert_equal 1, requests.length
    assert_operator server.port, :>, 0

    payload = JSON.parse(requests.first.fetch(:body))
    assert_equal 2, payload.length
    assert_equal [ "src/direct_1.rb", "src/direct_2.rb" ], payload.map { |row| row["entity"] }
    assert_match(/\ABasic /, requests.first.fetch(:authorization).to_s)
  ensure
    server&.stop
    WebMock.disable_net_connect!(allow_localhost: false)
  end

  test "does nothing when imports and mirrors are disabled" do
    user = User.create!(timezone: "UTC")
    mirror = user.wakatime_mirrors.create!(
      endpoint_url: "https://wakatime.com/api/v1",
      encrypted_api_key: "mirror-key"
    )
    create_heartbeat(
      user: user,
      source_type: :direct_entry,
      entity: "src/direct.rb"
    )
    Flipper.disable(:wakatime_imports_mirrors)

    stub_request(:post, "https://wakatime.com/api/v1/users/current/heartbeats.bulk")
      .to_return(status: 201, body: "{}")

    WakatimeMirrorSyncJob.perform_now(mirror.id)

    assert_not_requested :post, "https://wakatime.com/api/v1/users/current/heartbeats.bulk"
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

end
