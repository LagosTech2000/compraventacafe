# Production's domain goes through Cloudflare before Render. Without this,
# request.remote_ip is the Cloudflare server that relayed the request, which
# users and bots share: a bot probing /.env got that server's IP banned
# (rack-attack's scanner_ban) and the office behind it saw 429 for an hour.
# Trusting Cloudflare's published ranges makes remote_ip the visitor's own
# IP (from X-Forwarded-For), for rack-attack, the sign-in limit and the
# audit log. Only a request that really came through Cloudflare can name
# another IP: anything else that sends X-Forwarded-For is not trusted.
#
# Ranges: https://www.cloudflare.com/ips/ (they rarely change).
CLOUDFLARE_IP_RANGES = %w[
  173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22
  141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20
  197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13
  104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
  2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32
  2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
].map { |range| IPAddr.new(range) }.freeze

# Keeps Rails' defaults (loopback and private networks, where Render's own
# proxy lives).
Rails.application.config.action_dispatch.trusted_proxies =
  ActionDispatch::RemoteIp::TRUSTED_PROXIES + CLOUDFLARE_IP_RANGES
