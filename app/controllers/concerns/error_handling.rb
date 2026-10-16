# Turns every error into a Spanish alert so users never see a server error
# page. Expected errors (missing record, expired form, forbidden) are always
# handled. Unexpected errors are handled when config.x.friendly_errors is on
# (production); in development they raise so the developer sees the trace.
#
# The user only sees a generic message plus a reference code. The exception
# itself goes to the log and to Rails.error, tagged with the same code, and
# to the audit log (ErrorAudit) with its route, user and details.
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    # Declared first: rescue_from gives precedence to later declarations.
    rescue_from StandardError, with: :handle_unexpected_error
    rescue_from ActionController::ParameterMissing, with: :handle_bad_request
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActionController::RoutingError, with: :handle_page_not_found
    rescue_from ActionController::UnknownFormat, with: :handle_unknown_format
    rescue_from ActionController::InvalidAuthenticityToken, with: :handle_expired_form
    rescue_from Pundit::NotAuthorizedError, with: :handle_forbidden
    rescue_from ActiveRecord::StaleObjectError, with: :handle_stale_record
  end

  private
    def handle_forbidden(exception)
      audit_error(:forbidden, exception)
      respond_with_error t("errors.handled.forbidden"), status: :forbidden
    end

    def handle_not_found(exception)
      audit_error(:not_found, exception)
      respond_with_error t("errors.handled.not_found"), status: :not_found
    end

    def handle_page_not_found(exception)
      audit_error(:not_found, exception)
      respond_with_error t("errors.handled.page_not_found"), status: :not_found
    end

    # A page asked for in a format it does not have (bots asking for the
    # sign-in page as JSON or plain text): 406, not a server error.
    def handle_unknown_format(exception)
      audit_error(:not_acceptable, exception)
      respond_with_error t("errors.handled.not_acceptable"), status: :not_acceptable
    end

    def handle_bad_request(exception)
      audit_error(:bad_request, exception)
      respond_with_error t("errors.handled.bad_request"), status: :bad_request
    end

    # Someone else saved the same record (optimistic locking, lock_version)
    # after this form was opened: nothing is saved, the user reloads.
    def handle_stale_record(exception)
      audit_error(:conflict, exception)
      respond_with_error t("errors.handled.stale_record"), status: :conflict
    end

    def handle_expired_form(exception)
      audit_error(:unprocessable_content, exception)
      respond_with_error t("errors.handled.expired_form"), status: :unprocessable_content
    end

    # Past a rate_limit_per_user. A frame (the report's charts) gets the
    # alert inside it, so the rest of the page keeps working.
    def handle_rate_limited(rule, period)
      RateLimitAudit.record(request, rule:, period:, user: Current.user)
      message = t("errors.handled.rate_limited")
      if turbo_frame_request? && !modal_request?
        render "errors/frame", layout: false, status: :too_many_requests,
                               locals: { frame: request.headers["Turbo-Frame"], message: }
      elsif request.format.csv?
        redirect_back_or_to root_path, alert: message
      else
        respond_with_error message, status: :too_many_requests
      end
    end

    # Every error a user runs into goes to the audit log (ErrorAudit).
    def audit_error(status, exception)
      ErrorAudit.record(request:, status:, exception:, user: Current.user)
    end

    def handle_unexpected_error(exception)
      raise exception unless Rails.configuration.x.friendly_errors

      reference = request.request_id.to_s.first(8)
      Rails.error.report(exception, handled: true, context: { reference: reference, path: request.path })
      audit_error(:internal_server_error, exception)
      logger.error("[#{reference}] #{exception.class}: #{exception.message}\n#{Array(exception.backtrace).first(20).join("\n")}")

      respond_with_error t("errors.handled.unexpected", reference: reference),
                         status: :internal_server_error, redirect_page_loads: false
    end

    # Form submissions go back to the page they came from, with the alert.
    # Page loads go to the home page, or render an error page when that is
    # not safe: redirecting a failing page back to itself would loop.
    def respond_with_error(message, status:, redirect_page_loads: true)
      if !request.format.html?
        head status
      elsif modal_request?
        flash.now[:alert] = message
        render "errors/show", status: status
      elsif !(request.get? || request.head?)
        redirect_back_or_to root_path, alert: message
      elsif redirect_page_loads && request.path != root_path
        redirect_to root_path, alert: message
      else
        flash.now[:alert] = message
        render "errors/show", status: status
      end
    end
end
