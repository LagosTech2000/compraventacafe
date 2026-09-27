class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include ErrorHandling

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_request_context

  # Every action must ask its policy. Forgetting to authorize fails on purpose.
  after_action :verify_authorized

  private
    def pundit_user
      Current.user
    end

    # Context stamped on every audit event of this request.
    def set_request_context
      Current.ip_address = request.remote_ip
      Current.request_id = request.request_id
    end
end
