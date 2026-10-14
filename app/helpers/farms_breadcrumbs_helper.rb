# The way up through the farms module (shared/_breadcrumbs): Fincas › the
# farm › the payroll › this page. A payroll always shows its farm, wherever
# it was opened from, so the farm is one tap away.
module FarmsBreadcrumbsHelper
  def farm_crumbs(farm, *rest)
    [ [ t("farms.nav.farms"), farms_farms_path ], [ farm.display_name, farms_farm_path(farm) ], *rest ]
  end

  def payroll_crumbs(payroll, *rest, tab: nil)
    farm_crumbs(payroll.farm, [ payroll.name, farms_payroll_path(payroll, tab:) ], *rest)
  end
end
