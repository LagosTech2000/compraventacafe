class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include ErrorHandling
  include ModalSupport

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_request_context

  # Every action must ask its policy. Forgetting to authorize fails on purpose.
  after_action :verify_authorized

  # A screen that is expensive to serve (backup, CSV, charts): at most `to`
  # requests per user within `within`. Past it, the user gets an alert and
  # the first hit goes to the audit log (ErrorHandling#handle_rate_limited).
  def self.rate_limit_per_user(name:, to:, within:, **options)
    rate_limit to:, within:, name:, by: -> { Current.user.id }, with: -> { handle_rate_limited(name, within) }, **options
  end

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
