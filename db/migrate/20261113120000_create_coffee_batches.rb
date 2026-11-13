# Lots of purchased coffee (Fernando, 2026-11-13): made of shares of
# purchase invoices, with a limit of gross pounds, in a warehouse; they go
# on shipments instead of the invoices themselves. A shipment's invoices
# (2026-11-12) become one lot per shipment, each invoice whole.
# SQL only: no app models.
class CreateCoffeeBatches < ActiveRecord::Migration[8.1]
  def up
    create_table :coffee_batches do |t|
      t.integer :number, null: false
      t.references :warehouse, null: false, foreign_key: true
      t.string :coffee_state, null: false
      t.decimal :gross_limit, precision: 12, scale: 2, null: false
      t.date :batched_on, null: false
      t.text :observations
      t.references :shipment, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :coffee_batches, :number, unique: true
    add_index :coffee_batches, :batched_on

    create_table :coffee_batch_invoices do |t|
      t.references :coffee_batch, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true
      t.decimal :percent, precision: 5, scale: 2, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :coffee_batch_invoices, %i[coffee_batch_id invoice_id], unique: true

    execute <<~SQL
      INSERT INTO coffee_batches (number, warehouse_id, coffee_state, gross_limit, batched_on, shipment_id, created_by_id, created_at, updated_at)
      SELECT ROW_NUMBER() OVER (ORDER BY s.departed_at, s.id), s.warehouse_id, s.coffee_state,
             GREATEST(COALESCE((SELECT SUM(p.gross_weight) FROM purchases p JOIN shipment_invoices si2 ON si2.invoice_id = p.invoice_id
                                 WHERE si2.shipment_id = s.id AND p.voided_at IS NULL), 0), 1),
             (s.departed_at AT TIME ZONE 'America/Tegucigalpa')::date, s.id, MIN(si.created_by_id), NOW(), NOW()
        FROM shipments s JOIN shipment_invoices si ON si.shipment_id = s.id
       GROUP BY s.id
    SQL
    execute <<~SQL
      INSERT INTO coffee_batch_invoices (coffee_batch_id, invoice_id, percent, created_by_id, created_at, updated_at)
      SELECT cb.id, si.invoice_id, 100, si.created_by_id, si.created_at, si.updated_at
        FROM shipment_invoices si JOIN coffee_batches cb ON cb.shipment_id = si.shipment_id
    SQL
    drop_table :shipment_invoices
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
