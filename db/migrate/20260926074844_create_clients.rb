class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :person, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
