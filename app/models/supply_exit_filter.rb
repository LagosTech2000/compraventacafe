# The supplies that left without a loan (SupplyExit): by supply, reason,
# dates and text (the person or the observations).
class SupplyExitFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :supply_id, :id
  field :kind, :choice, in: SupplyExit::KINDS

  sorts exited_on: "supply_exits.exited_on",
        kind: "supply_exits.kind",
        supply: { sql: text("supplies.name"), joins: :supply },
        quantity: "supply_exits.quantity",
        person: { sql: text("people.first_names", "people.last_names"), joins: :person },
        amount: "supply_exits.amount"

  def apply(scope)
    scope = scope.where(exited_on: from..) if from
    scope = scope.where(exited_on: ..to) if to
    scope = scope.where(supply_id:) if supply_id
    scope = scope.where(kind:) if kind
    if q
      people = Person.where("people.first_names || ' ' || people.last_names ILIKE :q", q: like(q)).select(:id)
      scope = scope.where(person_id: people).or(scope.where("supply_exits.observations ILIKE ?", like(q)))
    end
    scope.includes(:supply, :person, :money_account).newest_first
  end
end
