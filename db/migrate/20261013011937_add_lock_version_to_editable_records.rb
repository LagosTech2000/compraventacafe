# Optimistic locking: two people saving the same record at once no longer
# overwrite each other; the second one is told to reload (ErrorHandling).
class AddLockVersionToEditableRecords < ActiveRecord::Migration[8.1]
  def change
    %i[purchases invoices loans payrolls].each do |table|
      add_column table, :lock_version, :integer, default: 0, null: false
    end
  end
end
