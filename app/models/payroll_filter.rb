# Payrolls list: by default the ones still being worked on (running or
# about to start), so a payroll created to start later is not hidden.
class PayrollFilter < ListFilter
  STATUSES = ([ "unfinished" ] + Payroll::STATUSES).freeze

  field :q, :text
  field :farm_id, :id
  field :kind, :choice, in: Payroll::KINDS
  field :status, :choice, in: STATUSES, default: "unfinished"

  def apply(scope)
    scope = scope.where("payrolls.name ILIKE ?", like(q)) if q
    scope = scope.where(farm_id:) if farm_id
    scope = scope.where(kind:) if kind
    scope = scope.public_send(status) if status
    scope.includes(:farm).newest_first
  end
end
