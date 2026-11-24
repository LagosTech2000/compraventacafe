# The loans' portfolio loaded from before the system (Fernando, 2026-11-23):
# their cash left before any account existed in it, so they move no money
# here (no account, out of Movimientos, Consolidación and the balances).
# Maintenance::LoansToCashBox marks them.
class AddOutsideCashToLoans < ActiveRecord::Migration[8.1]
  def change
    add_column :loans, :outside_cash, :boolean, default: false, null: false
  end
end
