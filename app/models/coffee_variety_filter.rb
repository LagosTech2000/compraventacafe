# Coffee varieties (Fincas → Variedades): by name and status, with how many
# farms and plots have each.
class CoffeeVarietyFilter < ListFilter
  STATUSES = %w[active inactive].freeze
  FARMS = "(SELECT COUNT(*) FROM farms WHERE coffee_varieties.id = ANY(farms.variety_ids))".freeze
  PLOTS = "(SELECT COUNT(*) FROM farm_plots WHERE coffee_varieties.id = ANY(farm_plots.variety_ids))".freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("coffee_varieties.name"), farms: FARMS, plots: PLOTS

  def apply(scope)
    scope = scope.where("coffee_varieties.name ILIKE ?", like(q)) if q
    scope = scope.where(active: status == "active") if status
    scope.select("coffee_varieties.*", "#{FARMS} AS farms_count", "#{PLOTS} AS plots_count").order(:name)
  end
end
