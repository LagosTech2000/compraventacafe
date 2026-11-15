# Supplies (Fernando, 2026-11-13):
# - An entry brings several supplies (one invoice of the supplier): its
#   lines go to supply_entry_lines; the entry keeps the total (one
#   investment) and the invoice uploaded is the investment's receipt.
# - Each supply of a loan is delivered or not: a line is pending until an
#   administrator marks it. The lines that exist were handed out with their
#   loan (delivered on its date).
# - The catalog moves from Préstamos to Comercialización → Insumos: whoever
#   had Préstamos → Insumos gets Comercialización → Insumos (nobody loses a
#   permission; a flag already there stays).
# SQL only: no app models (they change).
class RestructureSupplies < ActiveRecord::Migration[8.1]
  def up
    create_table :supply_entry_lines do |t|
      t.references :supply_entry, null: false, foreign_key: true
      t.references :supply, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.timestamps
    end
    execute <<~SQL
      INSERT INTO supply_entry_lines (supply_entry_id, supply_id, quantity, amount, created_at, updated_at)
      SELECT id, supply_id, quantity, amount, created_at, updated_at FROM supply_entries
    SQL
    remove_reference :supply_entries, :supply, index: true
    remove_column :supply_entries, :quantity

    add_column :loan_supplies, :delivered_on, :date
    add_reference :loan_supplies, :delivered_by, foreign_key: { to_table: :users }
    execute <<~SQL
      UPDATE loan_supplies SET delivered_on = loans.disbursed_on FROM loans WHERE loans.id = loan_supplies.loan_id
    SQL

    execute <<~SQL
      INSERT INTO permissions (user_id, module_key, submodule_key, can_read, can_create, can_update, can_destroy, created_at, updated_at)
      SELECT user_id, 'sales', 'supplies', can_read, can_create, can_update, can_destroy, NOW(), NOW()
        FROM permissions WHERE module_key = 'loans' AND submodule_key = 'supplies'
      ON CONFLICT (user_id, module_key, submodule_key) DO UPDATE
        SET can_read = permissions.can_read OR EXCLUDED.can_read,
            can_create = permissions.can_create OR EXCLUDED.can_create,
            can_update = permissions.can_update OR EXCLUDED.can_update,
            can_destroy = permissions.can_destroy OR EXCLUDED.can_destroy
    SQL
    execute "DELETE FROM permissions WHERE module_key = 'loans' AND submodule_key = 'supplies'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
