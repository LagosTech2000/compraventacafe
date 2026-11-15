# What the loans lent of each supply and whether it was handed out
# (Fernando, 2026-11-13: «al darle clic poder saber a quién se los debe»).
# Only the loans that take from the inventory; the ones still owed by default.
class SupplyDeliveryFilter < ListFilter
  STATUSES = %w[pending delivered all].freeze

  field :status, :choice, in: STATUSES, default: "pending"
  field :supply_id, :id
  field :q, :text

  sorts disbursed_on: "loans.disbursed_on",
        person: { sql: text("people.first_names", "people.last_names"), joins: { loan: :person } },
        supply: { sql: text("supplies.name"), joins: :supply },
        quantity: "loan_supplies.quantity",
        total: "loan_supplies.total",
        delivered_on: "loan_supplies.delivered_on"

  def apply(scope)
    scope = scope.to_deliver if status == "pending"
    scope = scope.delivered if status == "delivered"
    scope = scope.where(supply_id:) if supply_id
    scope = scope.where(loans: { person_id: Person.picker_search(q).select(:id) }) if q
    scope.includes(:supply, :delivered_by, loan: { person: :photo_info }).order("loans.disbursed_on ASC", "loan_supplies.id ASC")
  end
end
