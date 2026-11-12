# Administrators void and edit purchase invoices, even paid ones (Fernando,
# 2026-11-12): a voided invoice keeps its number, who voided it, when and
# why. Its observations are edited with it.
class AddVoidAndObservationsToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :voided_at, :datetime
    add_reference :invoices, :voided_by, foreign_key: { to_table: :users }
    add_column :invoices, :void_reason, :string
    add_column :invoices, :observations, :text
  end
end
