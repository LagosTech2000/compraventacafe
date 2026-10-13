# Writes an error the user ran into to the audit log (action "error"): who,
# the route, the status, the error and its reference code (the one the user
# sees), so an admin can follow it up. Errors of signed-in users are all
# kept; for visitors without a session only server errors (5xx), so bots
# probing addresses do not fill the log. Never raises: an error while
# auditing an error only goes to the application log.
#
#   ErrorAudit.record(request:, status: 404, exception:, user: Current.user)
#   ErrorAudit.from_env(env)   # errors outside the controllers (unknown route…)
class ErrorAudit
  MESSAGE_LIMIT = 1_000
  BACKTRACE_LINES = 8

  def self.record(request:, status:, exception: nil, user: nil)
    status = Rack::Utils.status_code(status)
    return if user.nil? && status < 500

    AuditEvent.record!(
      action: "error", label: "#{status} #{request.request_method} #{request.path}",
      user:, ip_address: request.remote_ip, request_id: request.request_id,
      details: details(request, status, exception)
    )
  rescue StandardError => error
    Rails.logger.error("[ErrorAudit] could not audit the error: #{error.class}: #{error.message}")
    nil
  end

  # From the exceptions app: the request that failed and its user, from the
  # session cookie (the controllers' own Current is gone by then).
  # Works on a copy of the env: the static error page that follows reads
  # its status from PATH_INFO ("/404"), which must stay as it is.
  def self.from_env(env)
    copy = env.dup
    copy["PATH_INFO"] = env["action_dispatch.original_path"] if env["action_dispatch.original_path"]
    request = ActionDispatch::Request.new(copy)
    exception = env["action_dispatch.exception"]
    status = exception ? ActionDispatch::ExceptionWrapper.status_code_for_exception(exception.class.name) : 500
    record(request:, status:, exception:, user: user_from_cookie(request))
  end

  def self.user_from_cookie(request)
    id = request.cookie_jar.signed[:session_id]
    id && Session.joins(:user).merge(User.active).find_by(id:)&.user
  rescue StandardError
    nil
  end

  def self.details(request, status, exception)
    params = request.filtered_parameters.except("controller", "action")
    {
      "status" => status,
      "method" => request.request_method,
      "path" => request.fullpath.first(500),
      "controller" => ([ request.params["controller"], request.params["action"] ].compact.join("#").presence),
      "error" => exception&.class&.name,
      "message" => exception&.message.to_s.first(MESSAGE_LIMIT).presence,
      "reference" => request.request_id.to_s.first(8),
      "params" => (params.to_json.first(MESSAGE_LIMIT) if params.any?),
      "referer" => request.referer&.first(500),
      "user_agent" => request.user_agent&.first(300),
      "turbo_frame" => request.headers["Turbo-Frame"],
      "backtrace" => (backtrace(exception) if status >= 500)
    }.compact
  end

  # The application's own lines first: where in our code it failed.
  def self.backtrace(exception)
    lines = Array(exception&.backtrace)
    app = lines.grep(%r{/app/|/lib/}).reject { |line| line.include?("/gems/") }
    (app.presence || lines).first(BACKTRACE_LINES).join("\n").presence
  end
end
