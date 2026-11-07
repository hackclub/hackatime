# Cloudflare and our edge proxy only set X-Forwarded-*. Rack prefers the
# Forwarded header, which neither proxy strips, so a client could choose its
# own request.ip (and pass req.cloudflare?) for Rack::Attack. Ignore it, as
# ActionDispatch::RemoteIp already does.
Rack::Request.forwarded_priority = [ :x_forwarded ]
