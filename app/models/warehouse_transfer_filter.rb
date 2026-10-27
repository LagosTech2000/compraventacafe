# Transfers between warehouses (Comercialización → Inventario → Traslados).
# Voided ones only when asked.
class WarehouseTransferFilter < ListFilter
  field :from, :date
  field :to, :date
  field :warehouse_id, :id
  field :coffee_state, :choice, in: Purchase::COFFEE_STATES
  field :voided, :choice, in: %w[1]

  sorts number: "warehouse_transfers.number", transferred_at: "warehouse_transfers.transferred_at",
        from_warehouse: { sql: text("warehouses.name"), joins: :from_warehouse },
        to_warehouse: { sql: text("warehouses.name"), joins: :to_warehouse },
        coffee_state: "warehouse_transfers.coffee_state", net_weight: "warehouse_transfers.net_weight"

  def apply(scope)
    scope = scope.where(transferred_at: Purchase.day_range(from..to)) if from || to
    scope = scope.where(from_warehouse_id: warehouse_id).or(scope.where(to_warehouse_id: warehouse_id)) if warehouse_id
    scope = scope.where(coffee_state:) if coffee_state
    scope = voided ? scope.where.not(voided_at: nil) : scope.active
    scope.includes(:from_warehouse, :to_warehouse).newest_first
  end
end
