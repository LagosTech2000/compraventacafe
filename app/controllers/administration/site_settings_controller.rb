module Administration
  # Configuración del sitio: the business's name, location and logo.
  class SiteSettingsController < ApplicationController
    before_action :set_site_setting

    def show
    end

    def edit
    end

    def update
      if @site_setting.update(site_setting_params)
        close_modal_with notice: t(".success"), fallback: administration_site_setting_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_site_setting
        @site_setting = authorize SiteSetting.instance
      end

      def site_setting_params
        params.expect(site_setting: [ :business_name, :location, :logo, :remove_logo ])
      end
  end
end
