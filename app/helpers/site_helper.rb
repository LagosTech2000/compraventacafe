# The business as an admin set it up (SiteSetting): name, location, logo.
module SiteHelper
  # Read once per page, without the logo's bytes.
  def site_setting
    @site_setting_for_page ||= SiteSetting.current
  end

  def business_name = site_setting.business_name
  def business_location = site_setting.location

  # The logo, or the coffee bean while there is none. Decorative: the
  # business name always goes next to it.
  LOGO_STYLES = {
    nav: [ "size-9 rounded-full", "size-5" ],
    sign_in: [ "size-14 rounded-2xl", "size-8" ]
  }.freeze

  def business_logo(style = :nav)
    frame, bean = LOGO_STYLES.fetch(style)
    if site_setting.logo?
      image_tag site_logo_path(v: site_setting.logo_version), alt: "",
                class: "#{frame} shrink-0 bg-surface object-contain ring-1 ring-line/60"
    else
      tag.span(icon(:bean, css: bean), class: "grid #{frame} shrink-0 place-items-center bg-primary text-on-primary",
                                       style: "box-shadow: var(--shadow-primary)")
    end
  end
end
