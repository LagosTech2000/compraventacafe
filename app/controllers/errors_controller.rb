# The address asked for does not exist (the catch-all route). Raising the
# routing error lets ErrorHandling do what it does for every error: a
# Spanish alert, back to the home page, and the audit log.
class ErrorsController < ApplicationController
  skip_after_action :verify_authorized

  def not_found
    raise ActionController::RoutingError, "No route matches #{request.request_method} #{request.path}"
  end
end
