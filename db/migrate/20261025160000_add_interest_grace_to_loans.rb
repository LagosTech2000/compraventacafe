# A loan to an intermediary can skip the interest of its first 10 days
# (Fernando, 2026-10-24); from day 11 it runs as usual.
class AddInterestGraceToLoans < ActiveRecord::Migration[8.1]
  def change
    add_column :loans, :interest_grace, :boolean, default: false, null: false
  end
end
