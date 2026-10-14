class SupplyFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("supplies.name"), unit: text("supplies.unit"), default_price: "supplies.default_price",
        status: "NOT supplies.active"

  def apply(scope)
    scope = scope.where("name ILIKE ?", like(q)) if q
    scope = scope.where(active: status == "active") if status
    scope.newest_first
  end
end
