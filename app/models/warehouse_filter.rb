# Warehouses (Comercialización → Bodegas), each with the net pounds it has
# of each coffee state (as CoffeeStock counts them), so they sort too.
class WarehouseFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  # Net pounds in a warehouse now, of one state or of all.
  def self.net_sql(state = nil)
    only = ->(column) { state ? " AND #{column} = #{connection.quote(state)}" : "" }
    <<~SQL.squish
      (COALESCE((SELECT SUM(net_weight) FROM purchases WHERE voided_at IS NULL AND warehouse_id = warehouses.id#{only.call("coffee_state")}), 0)
       - COALESCE((SELECT SUM(origin_net_weight) FROM shipments WHERE voided_at IS NULL AND warehouse_id = warehouses.id#{only.call("coffee_state")}), 0)
       - COALESCE((SELECT SUM(input_net_weight) FROM coffee_conversions WHERE voided_at IS NULL AND warehouse_id = warehouses.id#{only.call("from_state")}), 0)
       + COALESCE((SELECT SUM(output_net_weight) FROM coffee_conversions WHERE voided_at IS NULL AND finished_at IS NOT NULL
                   AND output_warehouse_id = warehouses.id#{only.call("to_state")}), 0)
       + COALESCE((SELECT SUM(net_weight) FROM warehouse_transfers WHERE voided_at IS NULL AND to_warehouse_id = warehouses.id#{only.call("coffee_state")}), 0)
       - COALESCE((SELECT SUM(net_weight) FROM warehouse_transfers WHERE voided_at IS NULL AND from_warehouse_id = warehouses.id#{only.call("coffee_state")}), 0))
    SQL
  end

  def self.connection = ActiveRecord::Base.connection

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("warehouses.name"), main: "warehouses.main", total: -> { WarehouseFilter.net_sql },
        **Purchase::COFFEE_STATES.to_h { |state| [ :"net_#{state}", -> { WarehouseFilter.net_sql(state) } ] }

  def apply(scope)
    scope = scope.where("warehouses.name ILIKE :q", q: like(q)) if q
    scope = scope.where(active: status == "active") if status
    columns = Purchase::COFFEE_STATES.map { |state| "#{self.class.net_sql(state)} AS net_#{state}" }
    scope.select("warehouses.*", *columns, "#{self.class.net_sql} AS net_total").order(main: :desc, name: :asc)
  end
end
