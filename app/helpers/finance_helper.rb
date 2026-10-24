module FinanceHelper
  # Where a movement opens (MoneyMovements' route), only for who may read
  # the module it belongs to.
  def movement_path(movement)
    return unless movement.route && Current.user.can?(MoneyMovements::MODULES.fetch(movement.source), :read)

    public_send(*movement.route)
  end

  # Other income and transfers are removed from the ledger itself (they
  # have no page of their own).
  def movement_removal_path(movement)
    case movement.source
    when "other_incomes" then finance_other_income_path(movement.id) if policy(OtherIncome).destroy?
    when "transfers" then finance_account_transfer_path(movement.id) if policy(AccountTransfer).destroy?
    end
  end

  # "+L 1,000.00" / "−L 1,000.00"
  def signed_money(value)
    value.to_d.negative? ? "−#{format_money(value.to_d.abs)}" : format_money(value)
  end
end
