# The entries of the supplies' inventory: by supply, dates and text. An
# entry brings one or more supplies (Fernando, 2026-11-13).
class SupplyEntryFilter < ListFilter
  field :from, :date
  field :to, :date
  field :q, :text
  field :supply_id, :id

  sorts received_on: "supply_entries.received_on",
        lines: "(SELECT COUNT(*) FROM supply_entry_lines WHERE supply_entry_lines.supply_entry_id = supply_entries.id)",
        amount: "supply_entries.amount",
        payee: text("supply_entries.payee"),
        receipt_number: text("supply_entries.receipt_number")

  def apply(scope)
    scope = scope.where(received_on: from..) if from
    scope = scope.where(received_on: ..to) if to
    scope = scope.where(id: SupplyEntryLine.where(supply_id:).select(:supply_entry_id)) if supply_id
    if q
      scope = scope.where("supply_entries.payee ILIKE :q OR supply_entries.receipt_number ILIKE :q OR supply_entries.observations ILIKE :q", q: like(q))
    end
    scope.includes(:created_by, lines: :supply, expense: :money_account).newest_first
  end
end
