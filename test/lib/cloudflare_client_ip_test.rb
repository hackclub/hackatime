require "test_helper"

class CloudflareClientIpTest < ActiveSupport::TestCase
  CLOUDFLARE_EDGE = "173.245.48.10"
  PROXY = "172.18.0.5"
  CLIENT = "203.0.113.7"
  ATTACKER = "198.51.100.9"
  CLOUDFLARE_RANGES = [ IPAddr.new("173.245.48.0/20") ].freeze

  # cloudflare-rails trusts Cloudflare ranges in production only.
  setup do
    @ip_filter = Rack::Request.ip_filter
    Rack::Request.ip_filter = ->(ip) { @ip_filter.call(ip) || CLOUDFLARE_RANGES.any? { _1.include?(ip) } }
  end

  teardown { Rack::Request.ip_filter = @ip_filter }

  test "an edge proxy that replaces X-Forwarded-For hides the client without the middleware" do
    env = request_env("REMOTE_ADDR" => "127.0.0.1", "HTTP_X_FORWARDED_FOR" => "#{CLOUDFLARE_EDGE}, #{PROXY}")

    assert_equal CLOUDFLARE_EDGE, Rack::Attack::Request.new(env).ip
  end

  test "uses CF-Connecting-IP when the edge proxy replaced X-Forwarded-For" do
    env = call_middleware("REMOTE_ADDR" => "127.0.0.1", "HTTP_X_FORWARDED_FOR" => "#{CLOUDFLARE_EDGE}, #{PROXY}")

    assert_client_ip CLIENT, env
  end

  test "keeps the Cloudflare edge in the forwarded chain" do
    env = call_middleware("REMOTE_ADDR" => "127.0.0.1", "HTTP_X_FORWARDED_FOR" => "#{CLOUDFLARE_EDGE}, #{PROXY}")

    assert_equal "#{CLIENT}, #{CLOUDFLARE_EDGE}, #{PROXY}", env["HTTP_X_FORWARDED_FOR"]
  end

  test "uses CF-Connecting-IP when the edge proxy preserved X-Forwarded-For" do
    env = call_middleware("REMOTE_ADDR" => "127.0.0.1", "HTTP_X_FORWARDED_FOR" => "10.1.1.1, #{CLIENT}, #{CLOUDFLARE_EDGE}, #{PROXY}")

    assert_client_ip CLIENT, env
  end

  test "ignores CF-Connecting-IP from clients that bypass Cloudflare" do
    env = call_middleware("REMOTE_ADDR" => ATTACKER)

    assert_client_ip ATTACKER, env
  end

  test "ignores a Cloudflare address forged before an untrusted hop" do
    env = call_middleware("REMOTE_ADDR" => "127.0.0.1", "HTTP_X_FORWARDED_FOR" => "#{CLOUDFLARE_EDGE}, #{ATTACKER}")

    assert_client_ip ATTACKER, env
  end

  test "ignores a client-supplied Forwarded header" do
    env = call_middleware(
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_X_FORWARDED_FOR" => "#{CLOUDFLARE_EDGE}, #{PROXY}",
      "HTTP_FORWARDED" => "for=#{ATTACKER}, for=#{CLOUDFLARE_EDGE}"
    )

    assert_client_ip CLIENT, env
  end

  test "ignores a Forwarded header that forges a Cloudflare edge" do
    env = call_middleware(
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_X_FORWARDED_FOR" => ATTACKER,
      "HTTP_FORWARDED" => "for=198.51.100.10, for=#{CLOUDFLARE_EDGE}"
    )

    assert_client_ip ATTACKER, env
  end

  test "ignores an invalid CF-Connecting-IP" do
    env = call_middleware(
      "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_X_FORWARDED_FOR" => "#{CLOUDFLARE_EDGE}, #{PROXY}",
      "HTTP_CF_CONNECTING_IP" => "not-an-ip"
    )

    assert_equal "#{CLOUDFLARE_EDGE}, #{PROXY}", env["HTTP_X_FORWARDED_FOR"]
  end

  private

  def request_env(headers)
    Rack::MockRequest.env_for("/", { "HTTP_CF_CONNECTING_IP" => CLIENT }.merge(headers))
  end

  def call_middleware(headers)
    captured = nil
    app = ActionDispatch::RemoteIp.new(->(env) { captured = env; [ 200, {}, [] ] }, true,
      ActionDispatch::RemoteIp::TRUSTED_PROXIES + CLOUDFLARE_RANGES)
    CloudflareClientIp.new(app, cloudflare_ips: -> { CLOUDFLARE_RANGES }).call(request_env(headers))
    captured
  end

  def assert_client_ip(expected, env)
    assert_equal expected, Rack::Attack::Request.new(env).ip
    assert_equal expected, ActionDispatch::Request.new(env).remote_ip
  end
end
