# Vehicle types (Comercialización → Vehículos → Tipos de vehículo).
class VehicleTypeFilter < ListFilter
  STATUSES = %w[active inactive].freeze
  VEHICLES = "(SELECT COUNT(*) FROM vehicles WHERE vehicles.vehicle_type_id = vehicle_types.id)".freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("vehicle_types.name"), vehicles: VEHICLES

  def apply(scope)
    scope = scope.where("vehicle_types.name ILIKE ?", like(q)) if q
    scope = scope.where(active: status == "active") if status
    scope.select("vehicle_types.*", "#{VEHICLES} AS vehicles_count").order(:name)
  end
end
