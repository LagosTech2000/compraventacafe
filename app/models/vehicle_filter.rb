# Vehicles (Comercialización → Vehículos).
class VehicleFilter < ListFilter
  STATUSES = %w[active inactive].freeze
  OWNERS = %w[own others].freeze
  SHIPMENTS = "(SELECT COUNT(*) FROM shipments WHERE shipments.vehicle_id = vehicles.id AND shipments.voided_at IS NULL)".freeze

  field :q, :text
  field :vehicle_type_id, :id
  field :owner, :choice, in: OWNERS
  field :status, :choice, in: STATUSES, default: "active"

  sorts plate: "vehicles.plate", vehicle_type: { sql: text("vehicle_types.name"), joins: :vehicle_type }, brand_model: text("vehicles.brand_model"), color: text("vehicles.color"),
        capacity_quintals: "vehicles.capacity_quintals", own: "vehicles.own", shipments: SHIPMENTS

  def apply(scope)
    scope = scope.where("vehicles.plate ILIKE :q OR vehicles.brand_model ILIKE :q OR vehicles.color ILIKE :q", q: like(q)) if q
    scope = scope.where(vehicle_type_id:) if vehicle_type_id
    scope = scope.where(own: owner == "own") if owner
    scope = scope.where(active: status == "active") if status
    scope.includes(:vehicle_type).select("vehicles.*", "#{SHIPMENTS} AS shipments_count").order(:plate)
  end
end
