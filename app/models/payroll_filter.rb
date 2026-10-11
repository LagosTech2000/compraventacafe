# Payrolls list: the active ones by default.
class PayrollFilter < ListFilter
  field :q, :text
  field :farm_id, :id
  field :kind, :choice, in: Payroll::KINDS
  field :status, :choice, in: Payroll::STATUSES, default: "active"

  def apply(scope)
    scope = scope.where("payrolls.name ILIKE ?", like(q)) if q
    scope = scope.where(farm_id:) if farm_id
    scope = scope.where(kind:) if kind
    scope = scope.public_send(status) if status
    scope.includes(:farm).newest_first
  end
end
