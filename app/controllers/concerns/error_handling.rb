# Turns every error into a Spanish alert so users never see a server error
# page. Expected errors (missing record, expired form, forbidden) are always
# handled. Unexpected errors are handled when config.x.friendly_errors is on
# (production); in development they raise so the developer sees the trace.
#
# The user only sees a generic message plus a reference code. The exception
# itself goes to the log and to Rails.error, tagged with the same code.
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    # Declared first: rescue_from gives precedence to later declarations.
    rescue_from StandardError, with: :handle_unexpected_error
    rescue_from ActionController::ParameterMissing, with: :handle_bad_request
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActionController::InvalidAuthenticityToken, with: :handle_expired_form
    rescue_from Pundit::NotAuthorizedError, with: :handle_forbidden
  end

  private
    def handle_forbidden
      respond_with_error t("errors.handled.forbidden"), status: :forbidden
    end

    def handle_not_found
      respond_with_error t("errors.handled.not_found"), status: :not_found
    end

    def handle_bad_request
      respond_with_error t("errors.handled.bad_request"), status: :bad_request
    end

    def handle_expired_form
      respond_with_error t("errors.handled.expired_form"), status: :unprocessable_content
    end

    def handle_unexpected_error(exception)
      raise exception unless Rails.configuration.x.friendly_errors

      reference = request.request_id.to_s.first(8)
      Rails.error.report(exception, handled: true, context: { reference: reference, path: request.path })
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
