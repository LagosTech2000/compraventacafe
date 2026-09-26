class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Every action must ask its policy. Forgetting to authorize fails on purpose.
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, with: :forbidden

  private
    def pundit_user
      Current.user
    end

    def forbidden
      redirect_back_or_to root_path, alert: t("authorization.forbidden")
    end
end
