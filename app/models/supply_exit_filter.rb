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
        supply: { sql: "(SELECT MIN(LOWER(supplies.name)) FROM supply_exit_lines JOIN supplies ON supplies.id = supply_exit_lines.supply_id " \
                       "WHERE supply_exit_lines.supply_exit_id = supply_exits.id)" },
        quantity: "(SELECT SUM(supply_exit_lines.quantity) FROM supply_exit_lines WHERE supply_exit_lines.supply_exit_id = supply_exits.id)",
        person: { sql: text("people.first_names", "people.last_names"), joins: :person },
        amount: "supply_exits.amount"

  def apply(scope)
    scope = scope.where(exited_on: from..) if from
    scope = scope.where(exited_on: ..to) if to
    scope = scope.where(id: SupplyExitLine.where(supply_id:).select(:supply_exit_id)) if supply_id
    scope = scope.where(kind:) if kind
    if q
      people = Person.search(q).select(:id)
      scope = scope.where(person_id: people).or(scope.where("supply_exits.observations ILIKE ?", like(q)))
    end
    scope.includes({ lines: :supply }, :person, :money_account).newest_first
  end
end
