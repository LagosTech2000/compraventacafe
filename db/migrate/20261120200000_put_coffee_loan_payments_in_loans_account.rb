# The loan payments with coffee enter the loans' account (Fernando,
# 2026-11-20: «que sea retroactivo»): the ones registered before, without
# an account, take it. Without a loans' account nothing changes.
class PutCoffeeLoanPaymentsInLoansAccount < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE loan_payments
      SET money_account_id = (SELECT id FROM money_accounts WHERE active AND 'loans' = ANY(default_for) ORDER BY id LIMIT 1)
      WHERE payment_method = 'coffee' AND money_account_id IS NULL
        AND EXISTS (SELECT 1 FROM money_accounts WHERE active AND 'loans' = ANY(default_for))
    SQL
  end

  def down
    # The payments with an account by hand are not told apart: nothing to undo.
  end
end
