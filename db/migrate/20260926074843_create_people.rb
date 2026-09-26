class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.string :first_names, null: false
      t.string :last_names, null: false
      t.string :dni
      t.string :rtn
      t.string :phone
      t.string :email
      t.text :address

      t.timestamps
    end
    # Plain indexes: format and uniqueness of dni/rtn are still open.
    add_index :people, :dni
    add_index :people, :rtn
    add_index :people, [ :last_names, :first_names ]
  end
end
