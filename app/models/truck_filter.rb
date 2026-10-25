# Trucks (Comercialización → Camiones).
class TruckFilter < ListFilter
  STATUSES = %w[active inactive].freeze
  OWNERS = %w[own others].freeze
  SHIPMENTS = "(SELECT COUNT(*) FROM shipments WHERE shipments.truck_id = trucks.id AND shipments.voided_at IS NULL)".freeze

  field :q, :text
  field :owner, :choice, in: OWNERS
  field :status, :choice, in: STATUSES, default: "active"

  sorts plate: "trucks.plate", brand_model: text("trucks.brand_model"), color: text("trucks.color"),
        capacity_quintals: "trucks.capacity_quintals", own: "trucks.own", shipments: SHIPMENTS

  def apply(scope)
    scope = scope.where("trucks.plate ILIKE :q OR trucks.brand_model ILIKE :q OR trucks.color ILIKE :q", q: like(q)) if q
    scope = scope.where(own: owner == "own") if owner
    scope = scope.where(active: status == "active") if status
    scope.select("trucks.*", "#{SHIPMENTS} AS shipments_count").order(:plate)
  end
end
