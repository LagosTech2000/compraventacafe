# Only one account can be the loans' one (MoneyAccount::LOANS).
class AddOneLoansAccountIndexToMoneyAccounts < ActiveRecord::Migration[8.1]
  def change
    add_index :money_accounts, "(true)", unique: true, where: "'loans' = ANY (default_for)", name: "index_money_accounts_one_for_loans"
  end
end
