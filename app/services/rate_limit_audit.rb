# Writes to the audit log (action "rate_limited") that an IP hit a request
# limit: rack-attack's (config/initializers/rack_attack.rb) or a screen's
# rate_limit. Only the first time per IP, rule and period, so a flood of
# blocked requests is one event. Never raises.
#
#   RateLimitAudit.record(request)                       # rack-attack
#   RateLimitAudit.record(request, rule: "backup", period: 1.hour, user:)
class RateLimitAudit
  def self.record(request, rule: nil, period: nil, user: nil)
    rule ||= request.env["rack.attack.matched"].to_s
    period ||= (request.env["rack.attack.match_data"] || {})[:period] || Rack::Attack::SCANNER_BAN
    ip = Rack::Attack.client_ip(request)
    return unless Rack::Attack.cache.store.write("audited/#{rule}/#{ip}", true, unless_exist: true, expires_in: period)

    request = ActionDispatch::Request.new(request.env)
    AuditEvent.record!(
      action: "rate_limited", label: "#{rule} #{request.request_method} #{request.path}".truncate(255),
      user: user || ErrorAudit.user_from_cookie(request), ip_address: ip, request_id: request.request_id,
      details: {
        "rule" => rule,
        "method" => request.request_method,
        "path" => request.fullpath.first(500),
        "user_agent" => request.user_agent&.first(300)
      }
    )
  rescue StandardError => error
    Rails.logger.error("[RateLimitAudit] could not audit the limit: #{error.class}: #{error.message}")
    nil
  end
end
