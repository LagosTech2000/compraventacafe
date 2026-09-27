class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.integer :number, null: false
      t.references :producer, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.date :issued_on, null: false
      t.string :payment_status, null: false
      t.string :payment_method
      t.date :paid_on

      t.timestamps
    end
    add_index :invoices, :number, unique: true
    add_index :invoices, :payment_status
  end
end
