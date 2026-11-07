require "ipaddr"

# Cloudflare connects to our edge proxy, which may replace X-Forwarded-For with
# the Cloudflare address. When the trusted proxy chain shows a Cloudflare edge,
# CF-Connecting-IP is the client, so prepend it to X-Forwarded-For for
# Rack::Attack and ActionDispatch::RemoteIp. The rest of the chain must stay so
# req.cloudflare? still sees the edge.
class CloudflareClientIp
  def initialize(app, cloudflare_ips: -> { CloudflareRails::Importer.cloudflare_ips })
    @app = app
    @cloudflare_ips = cloudflare_ips
  end

  def call(env)
    request = Rack::Request.new(env)
    client_ip = parse_ip(request.get_header("HTTP_CF_CONNECTING_IP"))
    if client_ip && via_cloudflare?(request)
      env["HTTP_X_FORWARDED_FOR"] = [ client_ip.to_s, env["HTTP_X_FORWARDED_FOR"].presence ].compact.join(", ")
    end

    @app.call(env)
  end

  private

  def via_cloudflare?(request)
    cloudflare_ips = @cloudflare_ips.call
    chain = [ request.get_header("REMOTE_ADDR"), *Array(request.forwarded_for).reverse ]

    chain.map { parse_ip(_1) }
      .take_while { |ip| ip && (cloudflare_ip?(cloudflare_ips, ip) || request.trusted_proxy?(ip.to_s)) }
      .any? { |ip| cloudflare_ip?(cloudflare_ips, ip) }
  end

  def cloudflare_ip?(cloudflare_ips, ip)
    cloudflare_ips.any? { |range| range.family == ip.family && range.include?(ip) }
  end

  def parse_ip(value)
    IPAddr.new(value.to_s.strip)
  rescue IPAddr::Error
    nil
  end
end
