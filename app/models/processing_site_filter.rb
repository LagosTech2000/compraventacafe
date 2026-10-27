# Processing sites (Comercialización → Procesos → Lugares).
class ProcessingSiteFilter < ListFilter
  STATUSES = %w[active inactive].freeze
  PROCESSES = "(SELECT COUNT(*) FROM coffee_conversions WHERE coffee_conversions.processing_site_id = processing_sites.id AND coffee_conversions.voided_at IS NULL)".freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: text("processing_sites.name"), own: "processing_sites.own", processes: PROCESSES

  def apply(scope)
    scope = scope.where("processing_sites.name ILIKE ?", like(q)) if q
    scope = scope.where(active: status == "active") if status
    scope.select("processing_sites.*", "#{PROCESSES} AS processes_count").order(:name)
  end
end
