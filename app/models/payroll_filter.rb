# Payrolls list: by default the ones still being worked on (running or
# about to start), so a payroll created to start later is not hidden.
class PayrollFilter < ListFilter
  STATUSES = ([ "unfinished" ] + Payroll::STATUSES).freeze

  field :q, :text
  field :farm_id, :id
  field :kind, :choice, in: Payroll::KINDS
  field :status, :choice, in: STATUSES, default: "unfinished"

  # Status in the order of Payroll::STATUSES (active, upcoming, finished).
  sorts name: text("payrolls.name"), farm: { sql: text("farms.name"), joins: :farm },
        kind: "payrolls.kind", pay_frequency: "payrolls.pay_frequency", dates: [ "payrolls.starts_on", "payrolls.ends_on" ],
        status: lambda {
          today = ActiveRecord::Base.connection.quote(Time.zone.today)
          "CASE WHEN payrolls.starts_on > #{today} THEN 1 WHEN payrolls.ends_on < #{today} THEN 2 ELSE 0 END"
        }

  def apply(scope)
    scope = scope.where("payrolls.name ILIKE ?", like(q)) if q
    scope = scope.where(farm_id:) if farm_id
    scope = scope.where(kind:) if kind
    scope = scope.public_send(status) if status
    scope.includes(:farm).newest_first
  end
end
