# Physical counts (Comercialización → Inventario → Conteos). Voided ones
# only when asked.
class StockCountFilter < ListFilter
  field :from, :date
  field :to, :date
  field :warehouse_id, :id
  field :coffee_state, :choice, in: Purchase::COFFEE_STATES
  field :voided, :choice, in: %w[1]

  sorts number: "stock_counts.number", counted_at: "stock_counts.counted_at",
        warehouse: { sql: text("warehouses.name"), joins: :warehouse },
        coffee_state: "stock_counts.coffee_state", counted_gross: "stock_counts.counted_gross",
        gross_weight: "stock_counts.gross_weight", net_weight: "stock_counts.net_weight", reason: "stock_counts.reason"

  def apply(scope)
    scope = scope.where(counted_at: Purchase.day_range(from..to)) if from || to
    scope = scope.where(warehouse_id:) if warehouse_id
    scope = scope.where(coffee_state:) if coffee_state
    scope = voided ? scope.where.not(voided_at: nil) : scope.active
    scope.includes(:warehouse, :created_by).newest_first
  end
end
