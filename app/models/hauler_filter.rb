class HaulerFilter < ListFilter
  STATUSES = %w[active inactive].freeze

  field :q, :text
  field :status, :choice, in: STATUSES, default: "active"

  sorts name: { sql: text("people.first_names", "people.last_names"), joins: :person },
        phone: { sql: "people.phone", joins: :person },
        commission_percent: "haulers.commission_percent",
        can_price: "haulers.can_price",
        commissions: "commissions_total",
        paid: "paid_total",
        balance: "balance_total"

  def apply(scope)
    scope = scope.where(person_id: Person.search(q).select(:id)) if q
    scope = scope.where(active: status == "active") if status
    scope.with_totals.includes(person: :photo_info).newest_first
  end
end
