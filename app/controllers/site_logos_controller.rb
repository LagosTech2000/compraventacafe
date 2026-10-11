# The business's logo (SiteSetting), for the navigation bar and the sign-in
# page, so it is public. Links carry the logo's version (?v=), so browsers
# keep it for a long time and ask again only when it changes.
class SiteLogosController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized

  def show
    setting = SiteSetting.first
    return head :not_found unless setting&.logo?

    expires_in 1.year, public: true if params[:v] == setting.logo_version.to_s
    send_data setting.logo_data, type: setting.logo_content_type, disposition: "inline",
                                 filename: setting.logo_filename || "logo"
  end
end
