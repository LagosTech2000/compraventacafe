# Invoices are paid in one or more payments ("abonos"): an invoice with some
# paid is "partial". Each invoice already marked as paid gets one payment
# for what it had to pay (its purchases minus the loans paid with them),
# on its payment date and with its payment method.
class CreateInvoicePayments < ActiveRecord::Migration[8.1]
  def up
    create_table :invoice_payments do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.date :paid_on, null: false
      t.string :payment_method, null: false
      t.timestamps
    end
    add_index :invoice_payments, [ :invoice_id, :paid_on ]

    execute <<~SQL
      INSERT INTO invoice_payments (invoice_id, created_by_id, amount, paid_on, payment_method, created_at, updated_at)
      SELECT invoices.id, invoices.created_by_id,
             COALESCE((SELECT SUM(purchases.total) FROM purchases WHERE purchases.invoice_id = invoices.id), 0)
             - COALESCE((SELECT SUM(loan_payments.amount) FROM loan_payments
                         JOIN purchases ON purchases.id = loan_payments.purchase_id
                         WHERE purchases.invoice_id = invoices.id), 0),
             COALESCE(invoices.paid_on, invoices.issued_on), COALESCE(invoices.payment_method, 'cash'), NOW(), NOW()
      FROM invoices
      WHERE invoices.payment_status = 'paid'
    SQL
  end

  def down
    drop_table :invoice_payments
  end
end
