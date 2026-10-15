# Request limits in front of the whole app (rack-attack), before any
# controller runs:
#
#   requests_per_ip  every client IP gets REQUEST_LIMIT requests per
#                    REQUEST_PERIOD. High on purpose: the whole office may
#                    share one public IP (Starlink), and live filters, charts
#                    and infinite scroll make many small requests, and a
#                    save refreshes every open tab (live updates). Assets,
#                    the logo and the health check do not count.
#   scanner_ban      an IP that asks for addresses used to probe for holes
#                    (/wp-admin, /.env, *.php…) SCANNER_HITS times within
#                    SCANNER_WINDOW is banned for SCANNER_BAN. None of those
#                    addresses exist in this app, so each of them is answered
#                    429 right away too. The ban leaves out the same paths
#                    (assets, icons, logo, /up): a page that loads must not
#                    lose its icon or styles to a ban.
#
# Both answer 429 with the static Spanish page public/429.html. The first
# time an IP hits a limit in each period it goes to the audit log (action
# "rate_limited"), not every blocked request, so an attack cannot fill it.
#
# The sign-in form has its own, stricter limit (SessionsController), and the
# expensive screens one per user (rate_limit in their controllers).
#
# Tests turn it off; the specs that check it turn it on (spec/support/rate_limits.rb).
class Rack::Attack
  REQUEST_LIMIT = 3_000
  REQUEST_PERIOD = 5.minutes
  SCANNER_HITS = 3
  SCANNER_WINDOW = 10.minutes
  SCANNER_BAN = 1.hour
  UNCOUNTED_PATHS = %r{\A/(assets/|up\z|site_logo|icon\.|favicon\.|apple-touch-icon|robots\.txt\z)}
  SCANNER_PATHS = %r{
    \.(php\d?|aspx?|jsp|cgi|env|git|svn|sql|bak|old|swp|ini|yml)(/|\?|\z) |
    /(wp-|wordpress|phpmyadmin|pma|cgi-bin|xmlrpc|vendor/phpunit|\.git|\.env|\.aws|\.ssh|actuator|boaform|HNAP1)
  }xi
  PAGE = Rails.public_path.join("429.html").read.freeze

  # Its own memory: Rails.cache may be cleared, and this must not slow it.
  cache.store = ActiveSupport::Cache::MemoryStore.new(size: 16.megabytes)
  self.enabled = !Rails.env.test?

  # The client's IP as Rails sees it (X-Forwarded-For from Render's proxy).
  def self.client_ip(request)
    (request.env["action_dispatch.remote_ip"] || request.ip).to_s
  end

  throttle("requests_per_ip", limit: ->(_request) { REQUEST_LIMIT }, period: REQUEST_PERIOD) do |request|
    client_ip(request) unless request.path.match?(UNCOUNTED_PATHS)
  end

  blocklist("scanner_ban") do |request|
    next false if request.path.match?(UNCOUNTED_PATHS)

    Fail2Ban.filter("scanners/#{client_ip(request)}", maxretry: SCANNER_HITS, findtime: SCANNER_WINDOW, bantime: SCANNER_BAN) do
      request.path.match?(SCANNER_PATHS)
    end
  end

  self.throttled_responder = lambda do |request|
    retry_after = (request.env["rack.attack.match_data"] || {})[:period].to_i
    [ 429, { "content-type" => "text/html; charset=utf-8", "retry-after" => retry_after.to_s }, [ PAGE ] ]
  end

  self.blocklisted_responder = lambda do |_request|
    [ 429, { "content-type" => "text/html; charset=utf-8", "retry-after" => SCANNER_BAN.to_i.to_s }, [ PAGE ] ]
  end
end

ActiveSupport::Notifications.subscribe(/\A(throttle|blocklist)\.rack_attack\z/) do |_name, _start, _finish, _id, payload|
  RateLimitAudit.record(payload[:request])
end
