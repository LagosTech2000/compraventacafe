class CreatePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :permissions do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :module_key, null: false
      t.boolean :can_read, null: false, default: false
      t.boolean :can_create, null: false, default: false
      t.boolean :can_update, null: false, default: false
      t.boolean :can_destroy, null: false, default: false

      t.timestamps
    end
    add_index :permissions, [ :user_id, :module_key ], unique: true
  end
end
