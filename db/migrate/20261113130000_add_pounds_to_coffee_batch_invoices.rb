# A lot keeps the gross and net pounds it took of an invoice (Fernando,
# 2026-11-13: an edited purchase must not change the shipments): what a
# heavier purchase adds stays out of every lot; the percent is now only
# how much of the invoice is taken. SQL only: no app models.
class AddPoundsToCoffeeBatchInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column :coffee_batch_invoices, :gross_weight, :decimal, precision: 16, scale: 6, null: false, default: 0
    add_column :coffee_batch_invoices, :net_weight, :decimal, precision: 16, scale: 6, null: false, default: 0
    change_column :coffee_batch_invoices, :percent, :decimal, precision: 9, scale: 4, null: false

    execute <<~SQL
      UPDATE coffee_batch_invoices cbi
         SET gross_weight = ROUND(sums.gross * cbi.percent / 100, 6),
             net_weight = ROUND(sums.net * cbi.percent / 100, 6)
        FROM (SELECT invoice_id, COALESCE(SUM(gross_weight), 0) AS gross, COALESCE(SUM(net_weight), 0) AS net
                FROM purchases WHERE voided_at IS NULL GROUP BY invoice_id) sums
       WHERE sums.invoice_id = cbi.invoice_id
    SQL
  end

  def down
    change_column :coffee_batch_invoices, :percent, :decimal, precision: 5, scale: 2, null: false
    remove_column :coffee_batch_invoices, :net_weight
    remove_column :coffee_batch_invoices, :gross_weight
  end
end
