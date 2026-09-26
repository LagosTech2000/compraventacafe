class AddStructuredAddressToPeople < ActiveRecord::Migration[8.1]
  def change
    add_reference :people, :department, foreign_key: true
    add_reference :people, :municipality, foreign_key: true
    rename_column :people, :address, :address_line
  end
end
