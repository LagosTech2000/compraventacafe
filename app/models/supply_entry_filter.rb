# The entries of the supplies' inventory: by supply, dates and text.
class SupplyEntryFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :supply_id, :id

  sorts received_on: "supply_entries.received_on",
        supply: { sql: text("supplies.name"), joins: :supply },
        quantity: "supply_entries.quantity",
        amount: "supply_entries.amount",
        unit_cost: "supply_entries.amount / NULLIF(supply_entries.quantity, 0)",
        payee: text("supply_entries.payee")

  def apply(scope)
    scope = scope.where(received_on: from..) if from
    scope = scope.where(received_on: ..to) if to
    scope = scope.where(supply_id:) if supply_id
    if q
      scope = scope.where("supply_entries.payee ILIKE :q OR supply_entries.receipt_number ILIKE :q OR supply_entries.observations ILIKE :q", q: like(q))
    end
    scope.includes(:supply, :created_by, expense: :money_account).newest_first
  end
end
