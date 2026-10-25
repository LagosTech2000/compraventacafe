# Carriers (Comercialización → Transportistas).
class CarrierFilter < ListFilter
  STATUSES = %w[active inactive].freeze
  SHIPMENTS = "(SELECT COUNT(*) FROM shipments WHERE shipments.carrier_id = carriers.id AND shipments.voided_at IS NULL)".freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("carriers.name"), rtn: "carriers.rtn", phone: "carriers.phone", contact_name: text("carriers.contact_name"),
        shipments: SHIPMENTS

  def apply(scope)
    scope = scope.where("carriers.name ILIKE :q OR carriers.rtn ILIKE :q OR carriers.contact_name ILIKE :q", q: like(q)) if q
    scope = scope.where(active: status == "active") if status
    scope.select("carriers.*", "#{SHIPMENTS} AS shipments_count").order(:name)
  end
end
